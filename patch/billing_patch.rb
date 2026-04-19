# frozen_string_literal: true

# =============================================================================
# FarolChat Custom Billing Patch
# =============================================================================
#
# Pricing per account:
#   - Agente:          R$ 29,00/mês por agente
#   - Caixa de Entrada: R$ 49,90/mês por inbox
#   - Sem pagamento → account suspensa automaticamente
#
# Stripe Products & Prices:
#   - Starter (default): prod_U1Wfj45O12KroX / price_1T3TcgRpW3RxEdb4XZyvNCL7 (R$0)
#   - Agente:            prod_U1WgkObUCeHBoh / price_1T3TcxRpW3RxEdb4EhR9ExvH (R$29)
#   - Caixa de Entrada:  prod_U1WgFJBoUC9FQZ / price_1T3Tf9RpW3RxEdb4HWUkRxYA (R$49,90)
#
# Webhook: https://app.farolchat.com/enterprise/webhooks/stripe
# =============================================================================

FAROL_AGENT_PRICE_ID   = 'price_1T3TcxRpW3RxEdb4EhR9ExvH'.freeze
FAROL_INBOX_PRICE_ID   = 'price_1T3Tf9RpW3RxEdb4HWUkRxYA'.freeze
FAROL_STARTER_PRICE_ID = 'price_1T3TcgRpW3RxEdb4XZyvNCL7'.freeze

FAROL_AGENT_PRODUCT_ID   = 'prod_U1WgkObUCeHBoh'.freeze
FAROL_INBOX_PRODUCT_ID   = 'prod_U1WgFJBoUC9FQZ'.freeze
FAROL_STARTER_PRODUCT_ID = 'prod_U1Wfj45O12KroX'.freeze

# ===========================================================================
# Helper: Billable agents = total account users - SuperAdmins - 1 (owner)
# The owner (first user / account creator) is always free.
# ===========================================================================
def farol_billable_agents(account)
  total_users   = account.account_users.count
  super_admins  = account.account_users.joins(:user).where(users: { type: 'SuperAdmin' }).count
  [total_users - super_admins - 1, 0].max
end

Rails.application.config.after_initialize do
  Rails.logger.info 'BillingPatch: Loading FarolChat billing customizations...'

  # ============================================================================
  # 1. Configure CHATWOOT_CLOUD_PLANS in InstallationConfig
  # ============================================================================
  begin
    cloud_plans = [
      {
        'name' => 'Starter',
        'product_id' => [FAROL_STARTER_PRODUCT_ID],
        'price_ids' => [FAROL_STARTER_PRICE_ID],
        'default_quantity' => 1
      },
      {
        'name' => 'Profissional',
        'product_id' => [FAROL_AGENT_PRODUCT_ID],
        'price_ids' => [FAROL_AGENT_PRICE_ID]
      }
    ]

    ic = InstallationConfig.find_or_create_by(name: 'CHATWOOT_CLOUD_PLANS')
    ic.update!(serialized_value: { 'value' => cloud_plans }.with_indifferent_access, locked: false)
    Rails.logger.info "BillingPatch: CHATWOOT_CLOUD_PLANS configured (#{cloud_plans.size} plans)"
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to configure CHATWOOT_CLOUD_PLANS: #{e.message}"
  end

  # ============================================================================
  # 1a. Configure Stripe Billing Portal for subscription management + PIX
  # ============================================================================
  begin
    Stripe::BillingPortal::Configuration.update(
      'bpc_1T3TfJRpW3RxEdb4umvmUUd0',
      {
        features: {
          subscription_update: {
            enabled: true,
            default_allowed_updates: ['quantity'],
            products: [
              { product: FAROL_AGENT_PRODUCT_ID, prices: [FAROL_AGENT_PRICE_ID] },
              { product: FAROL_INBOX_PRODUCT_ID, prices: [FAROL_INBOX_PRICE_ID] }
            ]
          },
          subscription_cancel: {
            enabled: true,
            mode: 'at_period_end',
            cancellation_reason: {
              enabled: true,
              options: ['too_expensive', 'missing_features', 'switched_service', 'unused', 'other']
            }
          },
          payment_method_update: { enabled: true },
          invoice_history: { enabled: true }
        }
      }
    )
    Rails.logger.info 'BillingPatch: Stripe billing portal configured (subscription updates + payment methods + invoices)'
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to configure billing portal: #{e.message}"
  end

# 1b. Patch subscription action to fix custom_attributes overwrite
  #     Original Chatwoot code does a FULL REPLACE — we fix it to MERGE
  #     Also skip billing for Account 1 (super admin / FarolChat)
  # ============================================================================
  Enterprise::Api::V1::AccountsController.class_eval do
    def subscription
      # Account 1 (FarolChat super admin) is never billed
      if @account.id == 1
        Rails.logger.info "BillingPatch: Skipping billing for Account 1 (super admin)"
        head :no_content
        return
      end

      # Only ensure Stripe customer exists — do NOT create a subscription here.
      # Subscriptions are created only via checkout or update_quantities.
      if stripe_customer_id.blank? && @account.custom_attributes['is_creating_customer'].blank?
        @account.update(custom_attributes: @account.custom_attributes.merge('is_creating_customer' => true))
        # Create customer only (no subscription)
        Enterprise::CreateStripeCustomerJob.perform_later(@account)
      end
      head :no_content
    end
  end

  Rails.logger.info 'BillingPatch: Patched subscription action (merge fix + skip Account 1)'

  # ============================================================================
  # 2. Override CreateStripeCustomerService
  #    Creates subscription with 2 line items: agents + inboxes
  #    Uses EXISTING account limits (not 1/1) so existing accounts keep working
  # ============================================================================
  Enterprise::Billing::CreateStripeCustomerService.class_eval do
    # Override to check ALL subscription statuses (not just active)
    def existing_subscription?
      stripe_customer_id = account.custom_attributes['stripe_customer_id']
      return false if stripe_customer_id.blank?

      %w[active incomplete past_due trialing].each do |status|
        subscriptions = Stripe::Subscription.list({ customer: stripe_customer_id, status: status, limit: 1 })
        return true if subscriptions.data.present?
      end
      false
    end

    # Find the first active/incomplete/past_due subscription
    def find_active_subscription(customer_id)
      %w[active incomplete past_due trialing].each do |status|
        subs = Stripe::Subscription.list({ customer: customer_id, status: status, limit: 1 })
        return subs.data.first if subs.data.present?
      end
      nil
    end

    # perform: Only ensures the Stripe customer exists (called by subscription action).
    # Does NOT create a subscription — that is done by create_subscription.
    def perform
      customer_id = prepare_customer_id
      account.update!(
        custom_attributes: account.custom_attributes.merge(
          'stripe_customer_id' => customer_id,
          'plan_name' => 'Profissional',
          'is_creating_customer' => false
        )
      )
      Rails.logger.info "BillingPatch: Ensured Stripe customer #{customer_id} for account #{account.id} (#{account.name}) — NO subscription created"
    rescue StandardError => e
      Rails.logger.error "BillingPatch: Error ensuring customer for account #{account.id}: #{e.message}"
      account.update!(custom_attributes: account.custom_attributes.merge('is_creating_customer' => false))
      raise
    end

    # create_subscription: Creates a new subscription with given quantities.
    # Called by checkout and update_quantities when no active subscription exists.
    def create_subscription(num_agents, num_inboxes)
      return if existing_subscription?

      customer_id = account.custom_attributes['stripe_customer_id']
      customer_id = prepare_customer_id if customer_id.blank?

      subscription = Stripe::Subscription.create(
        {
          customer: customer_id,
          items: [
            { price: FAROL_AGENT_PRICE_ID, quantity: num_agents },
            { price: FAROL_INBOX_PRICE_ID, quantity: num_inboxes }
          ],
          collection_method: 'send_invoice',
          days_until_due: 3,
          billing_cycle_anchor: next_billing_anchor.to_i,
          proration_behavior: 'create_prorations',
          expand: ['latest_invoice']
        }
      )

      # Auto-finalize the invoice so it gets a hosted URL
      latest_inv = subscription.latest_invoice
      if latest_inv.is_a?(String)
        latest_inv = Stripe::Invoice.retrieve(latest_inv)
      end
      if latest_inv && latest_inv.status == 'draft'
        latest_inv = Stripe::Invoice.finalize_invoice(latest_inv.id)
        Stripe::Invoice.send_invoice(latest_inv.id) rescue nil
      end
      invoice_url = latest_inv&.hosted_invoice_url rescue nil

      account.update!(
        status: :active,
        limits: (account.limits || {}).merge('agents' => num_agents, 'inboxes' => num_inboxes),
        custom_attributes: account.custom_attributes.merge(
          'stripe_customer_id' => customer_id,
          'stripe_price_id' => FAROL_AGENT_PRICE_ID,
          'stripe_product_id' => FAROL_AGENT_PRODUCT_ID,
          'plan_name' => 'Profissional',
          'subscribed_quantity' => "#{num_agents} Usuários • #{num_inboxes} Conexões",
          'subscribed_agents' => num_agents,
          'subscribed_inboxes' => num_inboxes,
          'subscription_status' => subscription.status,
          'subscription_ends_on' => subscription['current_period_end'] ? Time.zone.at(subscription['current_period_end']).to_s : nil,
          'hosted_invoice_url' => invoice_url,
          'is_creating_customer' => false
        )
      )

      Rails.logger.info "BillingPatch: Created subscription #{subscription.id} for account #{account.id} (#{account.name}) — agents=#{num_agents}, inboxes=#{num_inboxes}"
      subscription
    rescue StandardError => e
      Rails.logger.error "BillingPatch: Error creating subscription for account #{account.id}: #{e.message}"
      raise
    end

    private

    # Calculate next billing anchor: day 5 of current or next month
    def next_billing_anchor
      now = Time.current
      anchor = Time.zone.local(now.year, now.month, 5)
      anchor = anchor.next_month if now.day >= 5
      anchor
    end
  end

  Rails.logger.info 'BillingPatch: Patched CreateStripeCustomerService (multi-item, preserves limits)'

  # ============================================================================
  # 3. Override HandleStripeEventService
  #    - Multi-item subscription support (agents + inboxes)
  #    - Account suspension on non-payment
  #    - Account reactivation on successful payment
  # ============================================================================
  Enterprise::Billing::HandleStripeEventService.class_eval do
    def perform(event:)
      @event = event

      case @event.type
      when 'customer.subscription.updated'
        process_subscription_updated_farol
      when 'customer.subscription.deleted'
        process_subscription_deleted_farol
      when 'invoice.payment_failed'
        process_payment_failed_farol
      when 'invoice.paid'
        process_payment_succeeded_farol
      else
        Rails.logger.debug { "BillingPatch: Unhandled event type: #{@event.type}" }
      end
    end

    private

    def process_subscription_updated_farol
      sub = @event.data.object
      acct = find_account_by_stripe_customer(sub.customer)
      return if acct.blank?

      # Extract quantities from subscription items
      agent_qty = 0
      inbox_qty = 0

      (sub.items&.data || []).each do |item|
        price_id = item.respond_to?(:price) ? item.price.id : item.dig('price', 'id')
        quantity = item.respond_to?(:quantity) ? item.quantity : item['quantity']

        case price_id
        when FAROL_AGENT_PRICE_ID
          agent_qty = quantity.to_i
        when FAROL_INBOX_PRICE_ID
          inbox_qty = quantity.to_i
        end
      end

      # Update account limits and attributes
      acct.update!(
        limits: (acct.limits || {}).merge('agents' => agent_qty, 'inboxes' => inbox_qty),
        custom_attributes: acct.custom_attributes.merge(
          'stripe_customer_id' => sub.customer,
          'stripe_price_id' => FAROL_AGENT_PRICE_ID,
          'stripe_product_id' => FAROL_AGENT_PRODUCT_ID,
          'plan_name' => 'Profissional',
          'subscribed_quantity' => "#{agent_qty} Usuários • #{inbox_qty} Conexões",
          'subscribed_agents' => agent_qty,
          'subscribed_inboxes' => inbox_qty,
          'subscription_status' => sub.status,
          'subscription_ends_on' => sub['current_period_end'] ? Time.zone.at(sub['current_period_end']).to_s : nil
        )
      )

      # Handle subscription status → account status
      handle_subscription_status(acct, sub.status)

      Rails.logger.info "BillingPatch: Account #{acct.id} (#{acct.name}) updated: agents=#{agent_qty}, inboxes=#{inbox_qty}, status=#{sub.status}"
    end

    def process_subscription_deleted_farol
      sub = @event.data.object
      acct = find_account_by_stripe_customer(sub.customer)
      return if acct.blank?

      # Suspend account when subscription is deleted/canceled
      acct.update!(
        status: :suspended,
        custom_attributes: acct.custom_attributes.merge(
          'subscription_status' => 'canceled',
          'plan_name' => 'Cancelado'
        )
      )

      Rails.logger.warn "BillingPatch: Account #{acct.id} (#{acct.name}) SUSPENDED - subscription deleted"
    end

    def process_payment_failed_farol
      invoice = @event.data.object
      acct = find_account_by_stripe_customer(invoice.customer)
      return if acct.blank?

      attempt = invoice.respond_to?(:attempt_count) ? invoice.attempt_count : 1
      Rails.logger.warn "BillingPatch: Payment failed for account #{acct.id} (#{acct.name}) - attempt #{attempt}"

      # With send_invoice, we don't auto-suspend on payment failure.
      # Account stays active while subscription exists (past_due is OK).
      # Suspension only happens when subscription is canceled/deleted.
    end

    def process_payment_succeeded_farol
      invoice = @event.data.object
      acct = find_account_by_stripe_customer(invoice.customer)
      return if acct.blank?

      return unless acct.suspended?

      acct.update!(
        status: :active,
        custom_attributes: acct.custom_attributes.merge('subscription_status' => 'active')
      )
      Rails.logger.info "BillingPatch: Account #{acct.id} (#{acct.name}) REACTIVATED after successful payment"
    end

    def handle_subscription_status(acct, status)
      case status
      when 'active', 'trialing', 'past_due', 'incomplete'
        # Keep account ACTIVE while subscription exists (even if payment pending)
        if acct.suspended?
          acct.update!(status: :active)
          Rails.logger.info "BillingPatch: Account #{acct.id} (#{acct.name}) REACTIVATED — subscription status: #{status}"
        end
      when 'canceled', 'incomplete_expired', 'unpaid'
        unless acct.suspended?
          acct.update!(status: :suspended)
          Rails.logger.warn "BillingPatch: Account #{acct.id} (#{acct.name}) SUSPENDED — #{status}"
        end
      end
    end

    def find_account_by_stripe_customer(customer_id)
      return nil if customer_id.blank?

      Account.where("custom_attributes->>'stripe_customer_id' = ?", customer_id).first
    end
  end

  Rails.logger.info 'BillingPatch: Patched HandleStripeEventService (multi-item + suspension)'

  # ============================================================================
  # 4. Patch AccountsController#limits + default_plan?
  #    - Override ENTIRE limits action (not just default_limits)
  #    - Always return agents + inboxes only (NO conversation/non_web_inbox limits)
  #    - Override default_plan? to always return false
  # ============================================================================
  Enterprise::Api::V1::AccountsController.class_eval do
    # Override checkout to auto-create Stripe customer if not exists
    def checkout
      # Account 1 (FarolChat super admin) never billed
      if @account.id == 1
        render json: { error: 'Conta administrativa não possui cobrança.' }, status: :unprocessable_entity
        return
      end

      begin
        service = Enterprise::Billing::CreateStripeCustomerService.new(account: @account)
        customer_id = stripe_customer_id

        # Ensure Stripe customer exists
        if customer_id.blank?
          Rails.logger.info "BillingPatch: checkout creating Stripe customer for account #{@account.id}"
          service.perform
          @account.reload
          customer_id = @account.custom_attributes['stripe_customer_id']
          unless customer_id.present?
            render json: { error: 'Erro ao configurar cobrança. Tente novamente.' }, status: :unprocessable_entity
            return
          end
        end

        # Check for active subscription
        subscription = service.find_active_subscription(customer_id)

        if subscription
          # Has active subscription — check for open invoice first
          invoices = Stripe::Invoice.list(customer: customer_id, status: 'open', limit: 1)
          if invoices.data.present? && invoices.data.first.hosted_invoice_url.present?
            Rails.logger.info "BillingPatch: checkout redirecting account #{@account.id} to open invoice"
            render json: { redirect_url: invoices.data.first.hosted_invoice_url }
          else
            # Go to billing portal
            Rails.logger.info "BillingPatch: checkout redirecting account #{@account.id} to billing portal"
            create_stripe_billing_session(customer_id)
          end
        else
          # No active subscription — create one with current limits
          existing_limits = @account.limits || {}
          num_agents  = [existing_limits['agents'].to_i, 1].max
          num_inboxes = [existing_limits['inboxes'].to_i, 1].max

          Rails.logger.info "BillingPatch: checkout creating subscription for account #{@account.id} (agents=#{num_agents}, inboxes=#{num_inboxes})"
          service.create_subscription(num_agents, num_inboxes)
          @account.reload

          invoice_url = @account.custom_attributes['hosted_invoice_url']
          if invoice_url.present?
            render json: { redirect_url: invoice_url }
          else
            create_stripe_billing_session(customer_id)
          end
        end
      rescue StandardError => e
        Rails.logger.error "BillingPatch: checkout error for account #{@account.id}: #{e.message}"
        render json: { error: 'Erro ao configurar cobrança. Tente novamente.' }, status: :unprocessable_entity
      end
    end

    # Override the ENTIRE limits action to never show conversation limits
    # consumed = billable agents (total - SuperAdmin - 1 owner)
    def limits
      account_limits = @account.limits || {}
      custom_limits = {
        'agents' => {
          'allowed' => account_limits['agents'].to_i,
          'consumed' => farol_billable_agents(@account)
        },
        'inboxes' => {
          'allowed' => account_limits['inboxes'].to_i,
          'consumed' => @account.inboxes.count
        },
        'conversation' => {
          'allowed' => 999_999,
          'consumed' => 0
        },
        'non_web_inboxes' => {
          'allowed' => 999_999,
          'consumed' => 0
        }
      }

      render json: { id: @account.id, limits: custom_limits }, status: :ok
    end
  end

  # Override default_plan? in BillingHelper to always return false
  # This prevents the Hacker/Starter plan conversation limit popup
  BillingHelper.module_eval do
    def default_plan?(_account)
      false
    end
  end

  # Set plan_name on all accounts that don't have one (prevents default_plan? from matching)
  begin
    Account.where.not(id: 1).find_each do |acct|
      lim = acct.limits || {}
      a_count = lim['agents'].to_i
      i_count = lim['inboxes'].to_i
      updates = {}
      updates['plan_name'] = 'Profissional' if acct.custom_attributes['plan_name'].blank?
      # Always refresh the formatted subscribed_quantity
      updates['subscribed_quantity'] = "#{a_count} Usuários • #{i_count} Conexões" if a_count > 0 || i_count > 0
      updates['subscribed_agents'] = a_count if a_count > 0
      updates['subscribed_inboxes'] = i_count if i_count > 0
      if updates.any?
        acct.update_column(:custom_attributes, acct.custom_attributes.merge(updates))
      end
    end
    Rails.logger.info 'BillingPatch: Set plan_name + subscribed_quantity on accounts'
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to set plan_name: #{e.message}"
  end

  Rails.logger.info 'BillingPatch: Patched limits action + default_plan? (no conversation limits)'

  # ============================================================================
  # 4c. update_quantities: Admin can change agents/inboxes directly from UI
  #     Syncs with Stripe subscription in real-time
  # ============================================================================
  Enterprise::Api::V1::AccountsController.class_eval do
    def update_quantities
      # Account 1 (FarolChat super admin) never billed
      if @account.id == 1
        render json: { error: 'Conta administrativa não possui cobrança.' }, status: :unprocessable_entity
        return
      end

      new_agents  = params[:agents].to_i
      new_inboxes = params[:inboxes].to_i

      # Validate minimums — billable = total - SuperAdmin - 1 (owner)
      current_agents_used  = farol_billable_agents(@account)
      current_inboxes_used = @account.inboxes.count

      if new_agents < 1
        render json: { error: 'Mínimo de 1 usuário (agente).' }, status: :unprocessable_entity
        return
      end

      if new_inboxes < 1
        render json: { error: 'Mínimo de 1 conexão (caixa de entrada).' }, status: :unprocessable_entity
        return
      end

      if new_agents < current_agents_used
        render json: { error: "Impossível reduzir para #{new_agents} agentes. Você possui #{current_agents_used} em uso. Remova agentes antes." }, status: :unprocessable_entity
        return
      end

      if new_inboxes < current_inboxes_used
        render json: { error: "Impossível reduzir para #{new_inboxes} conexões. Você possui #{current_inboxes_used} em uso. Remova caixas de entrada antes." }, status: :unprocessable_entity
        return
      end

      begin
        service = Enterprise::Billing::CreateStripeCustomerService.new(account: @account)

        # Ensure Stripe customer exists
        customer_id = stripe_customer_id
        if customer_id.blank?
          service.perform
          @account.reload
          customer_id = @account.custom_attributes['stripe_customer_id']
          unless customer_id.present?
            render json: { error: 'Erro ao criar cliente no Stripe. Tente novamente.' }, status: :unprocessable_entity
            return
          end
        end

        # Find active subscription — if none, create one with the requested quantities
        subscription = service.find_active_subscription(customer_id)

        unless subscription
          Rails.logger.info "BillingPatch: No active subscription for account #{@account.id}, creating new one (agents=#{new_agents}, inboxes=#{new_inboxes})"
          new_sub = service.create_subscription(new_agents, new_inboxes)
          @account.reload
          invoice_url = @account.custom_attributes['hosted_invoice_url']
          render json: {
            success: true,
            message: "Assinatura criada! #{new_agents} Agentes • #{new_inboxes} Conexões",
            agents: { allowed: new_agents, consumed: current_agents_used },
            inboxes: { allowed: new_inboxes, consumed: current_inboxes_used },
            invoice_url: invoice_url,
            subscription_status: new_sub&.status || 'active'
          }, status: :ok
          return
        end

        # Find subscription items for agents and inboxes
        agent_item = nil
        inbox_item = nil

        subscription.items.data.each do |item|
          price_id = item.price.id
          case price_id
          when FAROL_AGENT_PRICE_ID
            agent_item = item
          when FAROL_INBOX_PRICE_ID
            inbox_item = item
          end
        end

        # Build update items array
        items_update = []

        if agent_item
          items_update << { id: agent_item.id, quantity: new_agents } if agent_item.quantity != new_agents
        else
          # Agent item doesn't exist yet, add it
          items_update << { price: FAROL_AGENT_PRICE_ID, quantity: new_agents }
        end

        if inbox_item
          items_update << { id: inbox_item.id, quantity: new_inboxes } if inbox_item.quantity != new_inboxes
        else
          # Inbox item doesn't exist yet, add it
          items_update << { price: FAROL_INBOX_PRICE_ID, quantity: new_inboxes }
        end

        if items_update.empty?
          render json: {
            success: true,
            message: 'Quantidades já estão atualizadas.',
            agents: { allowed: new_agents, consumed: current_agents_used },
            inboxes: { allowed: new_inboxes, consumed: current_inboxes_used }
          }, status: :ok
          return
        end

        # ---- Void existing open invoice before updating subscription ----
        # This ensures we generate a single consolidated invoice with the new amounts
        begin
          open_invoices = Stripe::Invoice.list(customer: customer_id, status: 'open', limit: 10)
          open_invoices.data.each do |inv|
            Stripe::Invoice.void_invoice(inv.id)
            Rails.logger.info "BillingPatch: Voided open invoice #{inv.id} for account #{@account.id} before quantity update"
          end
        rescue => e
          Rails.logger.warn "BillingPatch: Could not void open invoices: #{e.message}"
        end

        # Update Stripe subscription — proration creates pending items
        updated_sub = Stripe::Subscription.update(
          subscription.id,
          {
            items: items_update,
            proration_behavior: 'always_invoice',
            expand: ['latest_invoice']
          }
        )

        # Finalize and send the new invoice with prorated amounts
        invoice_url = nil
        latest_inv = updated_sub.latest_invoice
        if latest_inv.is_a?(String)
          latest_inv = Stripe::Invoice.retrieve(latest_inv)
        end
        if latest_inv && %w[draft open].include?(latest_inv.status)
          if latest_inv.status == 'draft'
            latest_inv = Stripe::Invoice.finalize_invoice(latest_inv.id)
            Stripe::Invoice.send_invoice(latest_inv.id) rescue nil
          end
          invoice_url = latest_inv.hosted_invoice_url
        end

        # Update account limits and attributes
        @account.update!(
          limits: (@account.limits || {}).merge('agents' => new_agents, 'inboxes' => new_inboxes),
          custom_attributes: @account.custom_attributes.merge(
            'subscribed_quantity' => "#{new_agents} Usuários • #{new_inboxes} Conexões",
            'subscribed_agents' => new_agents,
            'subscribed_inboxes' => new_inboxes,
            'subscription_status' => updated_sub.status,
            'hosted_invoice_url' => invoice_url || @account.custom_attributes['hosted_invoice_url']
          )
        )

        Rails.logger.info "BillingPatch: Account #{@account.id} (#{@account.name}) quantities updated: agents=#{new_agents}, inboxes=#{new_inboxes}"

        render json: {
          success: true,
          message: "Assinatura atualizada! #{new_agents} Agentes • #{new_inboxes} Conexões",
          agents: { allowed: new_agents, consumed: current_agents_used },
          inboxes: { allowed: new_inboxes, consumed: current_inboxes_used },
          invoice_url: invoice_url,
          subscription_status: updated_sub.status
        }, status: :ok

      rescue Stripe::StripeError => e
        Rails.logger.error "BillingPatch: Stripe error updating quantities for account #{@account.id}: #{e.message}"
        render json: { error: "Erro Stripe: #{e.message}" }, status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error "BillingPatch: Error updating quantities for account #{@account.id}: #{e.message}"
        render json: { error: 'Erro ao atualizar assinatura. Tente novamente.' }, status: :unprocessable_entity
      end
    end
  end

  # Add route for update_quantities
  Rails.application.routes.append do
    namespace :enterprise, defaults: { format: 'json' } do
      namespace :api do
        namespace :v1 do
          resources :accounts, only: [] do
            member do
              post :update_quantities
            end
          end
        end
      end
    end
  end

  # Add Pundit policy method for update_quantities
  AccountPolicy.class_eval do
    def update_quantities?
      @account_user.administrator?
    end
  end

  Rails.logger.info 'BillingPatch: update_quantities endpoint + policy added'

  # ============================================================================
  # 4b. SuperAdmin: auto-link to all accounts + exclude from agent count
  # ============================================================================
  begin
    super_admin_ids = User.where(type: 'SuperAdmin').pluck(:id)
    if super_admin_ids.any?
      Account.where.not(id: 1).find_each do |acct|
        super_admin_ids.each do |sa_id|
          begin
            AccountUser.find_or_create_by!(account_id: acct.id, user_id: sa_id) do |au|
              au.role = :administrator
            end
            Rails.logger.info "BillingPatch: Auto-linked SuperAdmin user #{sa_id} to account #{acct.id}"
          rescue => e
            # Skip if already exists
          end
        end
      end
      Rails.logger.info "BillingPatch: SuperAdmin users linked to all accounts"
    end
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to link SuperAdmin: #{e.message}"
  end

  # Also auto-link SuperAdmin when new accounts are created
  Account.class_eval do
    after_create :link_super_admins

    private

    def link_super_admins
      return if id == 1
      User.where(type: 'SuperAdmin').find_each do |sa|
        AccountUser.find_or_create_by!(account: self, user: sa) do |au|
          au.role = :administrator
        end
      end
    rescue StandardError => e
      Rails.logger.error "BillingPatch: Failed to auto-link SuperAdmin to new account #{id}: #{e.message}"
    end
  end

  Rails.logger.info "BillingPatch: SuperAdmin auto-link on new accounts active"

  # ============================================================================
  # 5. Enforce limits: prevent adding agents/inboxes beyond subscription
  # ============================================================================

  # Block adding agents beyond limit
  AccountUser.class_eval do
    validate :check_agent_limit, on: :create

    private

    def check_agent_limit
      return unless account

      acct_limits = account.limits || {}
      max_agents = acct_limits['agents'].to_i
      return if max_agents.zero? # zero = unlimited (super admin account)

      current_agents = farol_billable_agents(account)
      return unless current_agents >= max_agents

      errors.add(:base, "Limite de agentes atingido (#{max_agents}). Aumente sua assinatura em Configurações > Billing.")
      Rails.logger.warn "BillingPatch: Agent limit blocked for account #{account.id} (#{current_agents}/#{max_agents})"
    end
  end

  # Block adding inboxes beyond limit
  Inbox.class_eval do
    validate :check_inbox_limit, on: :create

    private

    def check_inbox_limit
      return unless account

      acct_limits = account.limits || {}
      max_inboxes = acct_limits['inboxes'].to_i
      return if max_inboxes.zero? # zero = unlimited (super admin account)

      current_inboxes = account.inboxes.count
      return unless current_inboxes >= max_inboxes

      errors.add(:base, "Limite de caixas de entrada atingido (#{max_inboxes}). Aumente sua assinatura em Configurações > Billing.")
      Rails.logger.warn "BillingPatch: Inbox limit blocked for account #{account.id} (#{current_inboxes}/#{max_inboxes})"
    end
  end

  Rails.logger.info 'BillingPatch: Enforcement validators added (agents + inboxes)'

  # ============================================================================
  # 6. Block suspended accounts from sending messages
  # ============================================================================
  SendReplyJob.class_eval do
    original_perform = instance_method(:perform)

    define_method(:perform) do |message_id|
      message = Message.find_by(id: message_id)
      if message&.account&.suspended?
        Rails.logger.warn "BillingPatch: Message blocked - account #{message.account.id} is suspended"
        message.update!(
          status: :failed,
          content_attributes: (message.content_attributes || {}).merge(
            'external_error' => 'Conta suspensa por falta de pagamento. Regularize sua assinatura.'
          )
        )
        return
      end

      original_perform.bind(self).call(message_id)
    end
  end

  Rails.logger.info 'BillingPatch: Suspended account message blocking active'
  Rails.logger.info 'BillingPatch: All billing patches loaded successfully'
end
