# frozen_string_literal: true

# =============================================================================
# FarolChat Custom Billing Patch — ASAAS
# =============================================================================
#
# Pricing per account (configurable via SuperAdmin):
#   - Agente:           configurable per-user price/month
#   - Caixa de Entrada: configurable per-connection price/month
#   - Sem pagamento -> account suspensa automaticamente
#
# Asaas API:
#   - Production: https://api.asaas.com/v3
#   - Sandbox:    https://api-sandbox.asaas.com/v3
#
# SuperAdmin configs (InstallationConfig):
#   - ASAAS_API_TOKEN:    API key for Asaas
#   - ASAAS_AGENT_PRICE:  price per agent/month (BRL)
#   - ASAAS_INBOX_PRICE:  price per inbox/month (BRL)
#   - ASAAS_SANDBOX:      use sandbox environment (boolean)
#   - ASAAS_WEBHOOK_TOKEN: token to validate webhooks
# =============================================================================

require 'net/http'
require 'json'
require 'uri'

# ===========================================================================
# Helper: Billable agents = total account users - SuperAdmins - 1 (owner)
# ===========================================================================
def farol_billable_agents(account)
  total_users   = account.account_users.count
  super_admins  = account.account_users.joins(:user).where(users: { type: 'SuperAdmin' }).count
  [total_users - super_admins - 1, 0].max
end

# ===========================================================================
# Asaas HTTP client helper
# ===========================================================================
module AsaasClient
  class << self
    def base_url
      sandbox? ? 'https://api-sandbox.asaas.com/v3' : 'https://api.asaas.com/v3'
    end

    def api_token
      config_value('ASAAS_API_TOKEN').to_s
    end

    def agent_price
      val = config_value('ASAAS_AGENT_PRICE')
      val.present? ? val.to_f : 29.0
    end

    def inbox_price
      val = config_value('ASAAS_INBOX_PRICE')
      val.present? ? val.to_f : 49.90
    end

    def sandbox?
      val = config_value('ASAAS_SANDBOX')
      val == true || val == 'true'
    end

    def webhook_token
      config_value('ASAAS_WEBHOOK_TOKEN').to_s
    end

    def configured?
      api_token.present?
    end

    def get(path)
      request(:get, path)
    end

    def post(path, body = {})
      request(:post, path, body)
    end

    def put(path, body = {})
      request(:put, path, body)
    end

    def delete(path)
      request(:delete, path)
    end

    private

    def config_value(name)
      ic = InstallationConfig.find_by(name: name)
      return nil unless ic
      val = ic.serialized_value
      val.is_a?(Hash) ? val['value'] : val
    rescue StandardError
      nil
    end

    def request(method, path, body = nil)
      url = URI("#{base_url}#{path}")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      case method
      when :get    then req = Net::HTTP::Get.new(url)
      when :post   then req = Net::HTTP::Post.new(url)
      when :put    then req = Net::HTTP::Put.new(url)
      when :delete then req = Net::HTTP::Delete.new(url)
      end

      req['Content-Type'] = 'application/json'
      req['User-Agent'] = 'FarolChat/1.0'
      req['access_token'] = api_token
      req.body = body.to_json if body && %i[post put].include?(method)

      response = http.request(req)
      parsed = JSON.parse(response.body) rescue {}

      { status: response.code.to_i,
        success: response.code.to_i >= 200 && response.code.to_i < 300,
        data: parsed }
    rescue StandardError => e
      Rails.logger.error "AsaasClient: HTTP error (#{method.upcase} #{path}): #{e.message}"
      { status: 0, success: false, data: { 'error' => e.message } }
    end
  end
end

# ===========================================================================
# Middleware: Inject CPF/CNPJ collection modal into billing page
# ===========================================================================
class BillingCpfInjector
  SCRIPT = <<~JSBLOCK
  <script id="farol-billing-cpf">
  (function(){
    var OF=window.fetch;
    window.fetch=function(u,o){
      if(typeof u==='string'&&u.includes('/checkout')&&o&&o.method==='POST'){
        return OF.apply(this,arguments).then(function(r){
          var c=r.clone();
          return c.json().then(function(d){
            if(d.requires_cpf_cnpj){return showBillingModal(u,o);}
            return r;
          }).catch(function(){return r;});
        });
      }
      return OF.apply(this,arguments);
    };
    function showBillingModal(url,opts){
      return new Promise(function(resolve){
        var dk=document.documentElement.classList.contains('dark');
        var bg=dk?'#1f2937':'#ffffff';
        var fg=dk?'#f3f4f6':'#111827';
        var bd=dk?'#374151':'#e5e7eb';
        var ibg=dk?'#111827':'#ffffff';
        var ibd=dk?'#4b5563':'#d1d5db';
        var ov=document.createElement('div');
        ov.id='farol-cpf-ov';
        ov.style.cssText='position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:99999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px);';
        var md=document.createElement('div');
        md.style.cssText='background:'+bg+';color:'+fg+';border-radius:16px;padding:28px 32px;max-width:440px;width:92%;box-shadow:0 20px 60px rgba(0,0,0,0.3);border:1px solid '+bd+';';
        md.innerHTML=
          '<h3 style="margin:0 0 6px;font-size:18px;font-weight:700;">Dados para Cobran\u00e7a</h3>'+
          '<p style="margin:0 0 20px;font-size:13px;opacity:0.7;">Preencha os dados abaixo para ativar sua assinatura.</p>'+
          '<div style="margin-bottom:14px;"><label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Nome completo / Raz\u00e3o Social</label>'+
          '<input id="fc-name" type="text" placeholder="Nome ou Raz\u00e3o Social" style="width:100%;padding:10px 12px;border:1px solid '+ibd+';border-radius:8px;font-size:14px;box-sizing:border-box;background:'+ibg+';color:'+fg+';outline:none;" /></div>'+
          '<div style="margin-bottom:14px;"><label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">CPF ou CNPJ</label>'+
          '<input id="fc-cpf" type="text" placeholder="000.000.000-00" style="width:100%;padding:10px 12px;border:1px solid '+ibd+';border-radius:8px;font-size:14px;box-sizing:border-box;background:'+ibg+';color:'+fg+';outline:none;" /></div>'+
          '<div style="margin-bottom:20px;"><label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">E-mail para nota fiscal</label>'+
          '<input id="fc-email" type="email" placeholder="email@empresa.com" style="width:100%;padding:10px 12px;border:1px solid '+ibd+';border-radius:8px;font-size:14px;box-sizing:border-box;background:'+ibg+';color:'+fg+';outline:none;" /></div>'+
          '<div id="fc-err" style="display:none;color:#ef4444;font-size:13px;margin-bottom:12px;"></div>'+
          '<div style="display:flex;gap:10px;">'+
          '<button id="fc-ok" style="flex:1;padding:10px;background:#1f93ff;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer;">Confirmar</button>'+
          '<button id="fc-no" style="flex:1;padding:10px;background:'+(dk?'#374151':'#f3f4f6')+';color:'+fg+';border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer;">Cancelar</button></div>';
        ov.appendChild(md);
        document.body.appendChild(ov);
        setTimeout(function(){document.getElementById('fc-name').focus();},100);
        document.getElementById('fc-cpf').addEventListener('input',function(e){
          var v=e.target.value.replace(/\\D/g,'');
          if(v.length<=11){v=v.replace(/(\\d{3})(\\d)/,'$1.$2');v=v.replace(/(\\d{3})(\\d)/,'$1.$2');v=v.replace(/(\\d{3})(\\d{1,2})$/,'$1-$2');}
          else{v=v.substring(0,14);v=v.replace(/^(\\d{2})(\\d)/,'$1.$2');v=v.replace(/^(\\d{2})\\.(\\d{3})(\\d)/,'$1.$2.$3');v=v.replace(/\\.(\\d{3})(\\d)/,'.$1/$2');v=v.replace(/(\\d{4})(\\d)/,'$1-$2');}
          e.target.value=v;
        });
        document.getElementById('fc-no').addEventListener('click',function(){
          ov.remove();
          resolve(new Response(JSON.stringify({error:'Opera\u00e7\u00e3o cancelada.'}),{status:422,headers:{'Content-Type':'application/json'}}));
        });
        document.getElementById('fc-ok').addEventListener('click',function(){
          var nm=document.getElementById('fc-name').value.trim();
          var cpf=document.getElementById('fc-cpf').value.replace(/\\D/g,'');
          var em=document.getElementById('fc-email').value.trim();
          var er=document.getElementById('fc-err');
          if(!nm){er.style.display='block';er.textContent='Informe o nome.';return;}
          if(cpf.length!==11&&cpf.length!==14){er.style.display='block';er.textContent='CPF (11 d\u00edgitos) ou CNPJ (14 d\u00edgitos).';return;}
          if(!em||em.indexOf('@')<1){er.style.display='block';er.textContent='Informe um e-mail v\u00e1lido.';return;}
          er.style.display='none';
          document.getElementById('fc-ok').textContent='Aguarde...';
          document.getElementById('fc-ok').disabled=true;
          var body={};
          try{body=JSON.parse(opts.body||'{}');}catch(x){}
          body.cpf_cnpj=cpf;body.customer_name=nm;body.customer_email=em;
          var no=Object.assign({},opts,{body:JSON.stringify(body)});
          OF(url,no).then(function(r){ov.remove();resolve(r);}).catch(function(x){
            er.style.display='block';er.textContent='Erro: '+x.message;
            document.getElementById('fc-ok').textContent='Confirmar';
            document.getElementById('fc-ok').disabled=false;
          });
        });
      });
    }
  })();
  </script>
  JSBLOCK

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    ct = headers['Content-Type'] || headers['content-type'] || ''
    return [status, headers, response] unless status == 200 && ct.include?('text/html')

    begin
      body = String.new
      response.each { |part| body << part }
      response.close if response.respond_to?(:close)

      if body.include?('</head>') && !body.include?('farol-billing-cpf')
        body = body.sub('</head>', "#{SCRIPT}</head>")
        headers['Content-Length'] = body.bytesize.to_s if headers['Content-Length']
      end

      [status, headers, [body]]
    rescue => e
      Rails.logger.error "BillingCpfInjector error: #{e.message}"
      [status, headers, response]
    end
  end
end

Rails.application.config.middleware.insert_before(0, BillingCpfInjector)

Rails.application.config.after_initialize do
  Rails.logger.info 'BillingPatch: Loading FarolChat Asaas billing customizations...'

  # ============================================================================
  # 1. Configure InstallationConfig entries for Asaas billing
  # ============================================================================
  begin
    asaas_configs = [
      { name: 'ASAAS_API_TOKEN',     value: '',      display_title: 'Asaas API Token',
        description: 'Token de acesso da API Asaas (producao ou sandbox). Obtido em Minha Conta > Integracoes.' },
      { name: 'ASAAS_AGENT_PRICE',   value: '29.00', display_title: 'Preco por Agente (R$)',
        description: 'Valor mensal cobrado por cada agente/usuario na conta do cliente.' },
      { name: 'ASAAS_INBOX_PRICE',   value: '49.90', display_title: 'Preco por Conexao (R$)',
        description: 'Valor mensal cobrado por cada caixa de entrada (inbox/conexao) na conta do cliente.' },
      { name: 'ASAAS_SANDBOX',       value: false,   display_title: 'Asaas Sandbox',
        description: 'Usar ambiente de testes (sandbox) do Asaas. Desative para producao.' },
      { name: 'ASAAS_WEBHOOK_TOKEN', value: '',      display_title: 'Asaas Webhook Token',
        description: 'Token para validar webhooks do Asaas. Configure no painel Asaas em Integracoes > Webhooks.' }
    ]

    asaas_configs.each do |cfg|
      ic = InstallationConfig.find_or_initialize_by(name: cfg[:name])
      if ic.new_record?
        ic.serialized_value = { 'value' => cfg[:value] }.with_indifferent_access
        ic.locked = false
        ic.save!
        Rails.logger.info "BillingPatch: Created InstallationConfig: #{cfg[:name]}"
      else
        ic.update!(locked: false) if ic.locked?
      end
    end

    # Keep CHATWOOT_CLOUD_PLANS for enterprise features
    cloud_plans = [{ 'name' => 'Profissional', 'product_id' => ['asaas_professional'], 'price_ids' => ['asaas_agent_price'] }]
    ic = InstallationConfig.find_or_create_by(name: 'CHATWOOT_CLOUD_PLANS')
    ic.update!(serialized_value: { 'value' => cloud_plans }.with_indifferent_access, locked: false)

    Rails.logger.info 'BillingPatch: Asaas InstallationConfig entries configured'
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to configure InstallationConfig: #{e.message}"
  end

  # ============================================================================
  # 1b. Patch subscription action
  # ============================================================================
  Enterprise::Api::V1::AccountsController.class_eval do
    def subscription
      if @account.id == 1
        head :no_content
        return
      end
      unless AsaasClient.configured?
        head :no_content
        return
      end

      customer_id = @account.custom_attributes['asaas_customer_id']
      if customer_id.blank? && @account.custom_attributes['is_creating_customer'].blank?
        @account.update(custom_attributes: @account.custom_attributes.merge('is_creating_customer' => true))
        Enterprise::CreateStripeCustomerJob.perform_later(@account)
      end
      head :no_content
    end
  end

  Rails.logger.info 'BillingPatch: Patched subscription action for Asaas'

  # ============================================================================
  # 2. Override CreateStripeCustomerService for Asaas
  # ============================================================================
  Enterprise::Billing::CreateStripeCustomerService.class_eval do
    def perform
      return if account.id == 1
      return unless AsaasClient.configured?

      customer_id = account.custom_attributes['asaas_customer_id']
      if customer_id.blank?
        cpf_cnpj = account.custom_attributes['cpf_cnpj'].to_s.gsub(/\D/, '')
        if cpf_cnpj.blank?
          raise 'CPF ou CNPJ e obrigatorio. Informe na tela de cobranca.'
        end

        owner = account.account_users.where(role: :administrator).first&.user
        billing_name = account.custom_attributes['billing_name'].presence || account.name.presence || 'Cliente FarolChat'
        billing_email = account.custom_attributes['billing_email'].presence || owner&.email
        body = {
          name: billing_name,
          externalReference: "chatwoot_account_#{account.id}",
          notificationDisabled: false,
          cpfCnpj: cpf_cnpj
        }
        body[:email] = billing_email if billing_email.present?

        result = AsaasClient.post('/customers', body)
        if result[:success] && result[:data]['id'].present?
          customer_id = result[:data]['id']
          Rails.logger.info "BillingPatch: Created Asaas customer #{customer_id} for account #{account.id}"
        else
          error_msg = result[:data]['errors']&.map { |e| e['description'] }&.join(', ') || 'erro desconhecido'
          raise "Erro ao criar cliente no Asaas: #{error_msg}"
        end
      end

      account.update!(
        custom_attributes: account.custom_attributes.merge(
          'asaas_customer_id' => customer_id,
          'plan_name' => 'Profissional',
          'is_creating_customer' => false
        )
      )
    rescue StandardError => e
      account.update!(custom_attributes: account.custom_attributes.merge('is_creating_customer' => false))
      Rails.logger.error "BillingPatch: Error in perform for account #{account.id}: #{e.message}"
      raise
    end

    def existing_subscription?
      sub_id = account.custom_attributes['asaas_subscription_id']
      return false if sub_id.blank?
      result = AsaasClient.get("/subscriptions/#{sub_id}")
      return false unless result[:success]
      %w[ACTIVE].include?(result[:data]['status'])
    end

    def find_active_subscription(customer_id)
      sub_id = account.custom_attributes['asaas_subscription_id']
      return nil if sub_id.blank?
      result = AsaasClient.get("/subscriptions/#{sub_id}")
      return nil unless result[:success]
      return nil unless %w[ACTIVE].include?(result[:data]['status'])
      result[:data]
    end

    def create_subscription(num_agents, num_inboxes)
      return if existing_subscription?

      customer_id = account.custom_attributes['asaas_customer_id']
      if customer_id.blank?
        perform
        account.reload
        customer_id = account.custom_attributes['asaas_customer_id']
        raise 'Asaas customer not found' if customer_id.blank?
      end

      total_value = (num_agents * AsaasClient.agent_price) + (num_inboxes * AsaasClient.inbox_price)

      due_date = Date.current + 2

      body = {
        customer: customer_id,
        billingType: 'UNDEFINED',
        value: total_value.round(2),
        nextDueDate: due_date.strftime('%Y-%m-%d'),
        cycle: 'MONTHLY',
        description: "FarolChat - #{num_agents} Agentes + #{num_inboxes} Conexoes",
        externalReference: "chatwoot_account_#{account.id}"
      }

      result = AsaasClient.post('/subscriptions', body)
      unless result[:success] && result[:data]['id'].present?
        error_msg = result[:data]['errors']&.map { |e| e['description'] }&.join(', ') || 'erro desconhecido'
        raise "Erro ao criar assinatura no Asaas: #{error_msg}"
      end

      sub = result[:data]

      # Get payment link for first charge
      payment_url = nil
      payments_result = AsaasClient.get("/subscriptions/#{sub['id']}/payments?limit=1")
      if payments_result[:success] && payments_result[:data]['data']&.any?
        payment_url = payments_result[:data]['data'].first['invoiceUrl']
      end

      account.update!(
        status: :active,
        limits: (account.limits || {}).merge('agents' => num_agents, 'inboxes' => num_inboxes),
        custom_attributes: account.custom_attributes.merge(
          'asaas_customer_id' => customer_id,
          'asaas_subscription_id' => sub['id'],
          'plan_name' => 'Profissional',
          'subscribed_quantity' => "#{num_agents} Usuarios . #{num_inboxes} Conexoes",
          'subscribed_agents' => num_agents,
          'subscribed_inboxes' => num_inboxes,
          'subscription_status' => sub['status']&.downcase,
          'subscription_value' => total_value.round(2),
          'hosted_invoice_url' => payment_url,
          'is_creating_customer' => false
        )
      )

      Rails.logger.info "BillingPatch: Created Asaas subscription #{sub['id']} for account #{account.id} - R$#{total_value.round(2)}"
      sub
    end
  end

  Rails.logger.info 'BillingPatch: Patched CreateStripeCustomerService for Asaas'

  # ============================================================================
  # 3. Override HandleStripeEventService for Asaas webhooks
  # ============================================================================
  Enterprise::Billing::HandleStripeEventService.class_eval do
    def perform(event:)
      @event = event
      event_type = event[:event] || event['event']
      payment = event[:payment] || event['payment'] || {}
      subscription_data = event[:subscription] || event['subscription'] || {}

      case event_type
      when 'PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED'
        process_asaas_payment_received(payment)
      when 'PAYMENT_OVERDUE'
        process_asaas_payment_overdue(payment)
      when 'PAYMENT_DELETED', 'PAYMENT_REFUNDED'
        process_asaas_payment_deleted(payment)
      when 'SUBSCRIPTION_INACTIVATED', 'SUBSCRIPTION_DELETED'
        process_asaas_subscription_canceled(subscription_data)
      when 'SUBSCRIPTION_CREATED', 'SUBSCRIPTION_UPDATED'
        process_asaas_subscription_updated(subscription_data)
      else
        Rails.logger.debug { "BillingPatch: Unhandled Asaas event: #{event_type}" }
      end
    end

    private

    def process_asaas_payment_received(payment)
      acct = find_account_by_asaas_customer(payment['customer'])
      return if acct.blank?
      if acct.suspended?
        acct.update!(status: :active, custom_attributes: acct.custom_attributes.merge('subscription_status' => 'active'))
        Rails.logger.info "BillingPatch: Account #{acct.id} REACTIVATED after Asaas payment"
      end
    end

    def process_asaas_payment_overdue(payment)
      acct = find_account_by_asaas_customer(payment['customer'])
      return if acct.blank?
      return if acct.id == 1
      Rails.logger.warn "BillingPatch: Payment OVERDUE for account #{acct.id} - SUSPENDING"
      acct.update!(status: :suspended, custom_attributes: acct.custom_attributes.merge('subscription_status' => 'overdue'))
    end

    def process_asaas_payment_deleted(payment)
      acct = find_account_by_asaas_customer(payment['customer'])
      return if acct.blank?
      Rails.logger.warn "BillingPatch: Payment deleted/refunded for account #{acct.id}"
    end

    def process_asaas_subscription_canceled(subscription_data)
      sub_id = subscription_data['id']
      acct = find_account_by_asaas_subscription(sub_id) || find_account_by_asaas_customer(subscription_data['customer'])
      return if acct.blank?
      acct.update!(status: :suspended, custom_attributes: acct.custom_attributes.merge('subscription_status' => 'canceled', 'plan_name' => 'Cancelado'))
      Rails.logger.warn "BillingPatch: Account #{acct.id} SUSPENDED - Asaas subscription canceled"
    end

    def process_asaas_subscription_updated(subscription_data)
      sub_id = subscription_data['id']
      acct = find_account_by_asaas_subscription(sub_id) || find_account_by_asaas_customer(subscription_data['customer'])
      return if acct.blank?
      status = subscription_data['status']&.downcase || 'active'
      value = subscription_data['value']
      acct.update!(custom_attributes: acct.custom_attributes.merge('subscription_status' => status, 'subscription_value' => value, 'asaas_subscription_id' => sub_id))
      if status == 'active' && acct.suspended?
        acct.update!(status: :active)
      elsif %w[canceled inactive].include?(status) && !acct.suspended?
        acct.update!(status: :suspended)
      end
    end

    def find_account_by_asaas_customer(customer_id)
      return nil if customer_id.blank?
      Account.where("custom_attributes->>'asaas_customer_id' = ?", customer_id).first
    end

    def find_account_by_asaas_subscription(sub_id)
      return nil if sub_id.blank?
      Account.where("custom_attributes->>'asaas_subscription_id' = ?", sub_id).first
    end
  end

  Rails.logger.info 'BillingPatch: Patched HandleStripeEventService for Asaas'

  # ============================================================================
  # 3b. Asaas Webhook Controller
  # ============================================================================
  asaas_webhook_klass = Class.new(ActionController::API) do
    def receive
      payload = request.body.read
      data = JSON.parse(payload) rescue {}

      expected_token = AsaasClient.webhook_token
      if expected_token.present?
        received_token = request.headers['asaas-access-token'].to_s
        unless ActiveSupport::SecurityUtils.secure_compare(received_token, expected_token)
          Rails.logger.warn 'BillingPatch: Asaas webhook token mismatch'
          head :unauthorized
          return
        end
      end

      Rails.logger.info "BillingPatch: Asaas webhook received: #{data['event']}"
      begin
        Enterprise::Billing::HandleStripeEventService.new.perform(event: data)
      rescue StandardError => e
        Rails.logger.error "BillingPatch: Asaas webhook error: #{e.message}"
      end
      head :ok
    end
  end

  ::Webhooks.const_set(:AsaasController, asaas_webhook_klass) unless defined?(::Webhooks::AsaasController)

  # ============================================================================
  # 4. Patch AccountsController - limits, checkout, update_quantities, billing_config
  # ============================================================================
  Enterprise::Api::V1::AccountsController.class_eval do
    def billing_config
      render json: {
        agent_price: AsaasClient.agent_price,
        inbox_price: AsaasClient.inbox_price,
        configured: AsaasClient.configured?,
        sandbox: AsaasClient.sandbox?
      }, status: :ok
    end

    def checkout
      if @account.id == 1
        render json: { error: 'Conta administrativa nao possui cobranca.' }, status: :unprocessable_entity
        return
      end
      unless AsaasClient.configured?
        render json: { error: 'Sistema de pagamento nao configurado. Contate o administrador.' }, status: :unprocessable_entity
        return
      end

      # Collect billing data (CPF/CNPJ, name, email)
      cpf_cnpj = params[:cpf_cnpj].to_s.gsub(/\D/, '')
      customer_name = params[:customer_name].to_s.strip
      customer_email = params[:customer_email].to_s.strip

      if cpf_cnpj.present? || customer_name.present? || customer_email.present?
        attrs = @account.custom_attributes.dup
        attrs['cpf_cnpj'] = cpf_cnpj if cpf_cnpj.present?
        attrs['billing_name'] = customer_name if customer_name.present?
        attrs['billing_email'] = customer_email if customer_email.present?
        @account.update!(custom_attributes: attrs)
      elsif @account.custom_attributes['cpf_cnpj'].blank?
        render json: { error: 'Preencha os dados de cobranca.', requires_cpf_cnpj: true }, status: :unprocessable_entity
        return
      end

      begin
        service = Enterprise::Billing::CreateStripeCustomerService.new(account: @account)

        customer_id = @account.custom_attributes['asaas_customer_id']
        if customer_id.blank?
          service.perform
          @account.reload
          customer_id = @account.custom_attributes['asaas_customer_id']
          unless customer_id.present?
            render json: { error: 'Erro ao configurar cobranca. Tente novamente.' }, status: :unprocessable_entity
            return
          end
        elsif cpf_cnpj.present?
          # Update existing Asaas customer with new data
          update_data = { cpfCnpj: cpf_cnpj }
          update_data[:name] = @account.custom_attributes['billing_name'] if @account.custom_attributes['billing_name'].present?
          update_data[:email] = @account.custom_attributes['billing_email'] if @account.custom_attributes['billing_email'].present?
          AsaasClient.put("/customers/#{customer_id}", update_data)
        end

        sub_id = @account.custom_attributes['asaas_subscription_id']
        if sub_id.present?
          # Get latest pending payment URL
          payments_result = AsaasClient.get("/subscriptions/#{sub_id}/payments?status=PENDING&limit=1")
          if payments_result[:success] && payments_result[:data]['data']&.any?
            payment = payments_result[:data]['data'].first
            if payment['invoiceUrl'].present?
              render json: { redirect_url: payment['invoiceUrl'] }
              return
            end
          end

          # Try overdue payments
          payments_result = AsaasClient.get("/subscriptions/#{sub_id}/payments?status=OVERDUE&limit=1")
          if payments_result[:success] && payments_result[:data]['data']&.any?
            payment = payments_result[:data]['data'].first
            if payment['invoiceUrl'].present?
              render json: { redirect_url: payment['invoiceUrl'] }
              return
            end
          end

          render json: { message: 'Nenhuma cobranca pendente encontrada.' }
        else
          existing_limits = @account.limits || {}
          num_agents  = [existing_limits['agents'].to_i, 1].max
          num_inboxes = [existing_limits['inboxes'].to_i, 1].max

          service.create_subscription(num_agents, num_inboxes)
          @account.reload

          invoice_url = @account.custom_attributes['hosted_invoice_url']
          if invoice_url.present?
            render json: { redirect_url: invoice_url }
          else
            render json: { message: 'Assinatura criada! Verifique seu email para o link de pagamento.' }
          end
        end
      rescue StandardError => e
        Rails.logger.error "BillingPatch: checkout error for account #{@account.id}: #{e.message}"
        render json: { error: "Erro ao configurar cobranca: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def limits
      account_limits = @account.limits || {}
      custom_limits = {
        'agents'        => { 'allowed' => account_limits['agents'].to_i, 'consumed' => farol_billable_agents(@account) },
        'inboxes'       => { 'allowed' => account_limits['inboxes'].to_i, 'consumed' => @account.inboxes.count },
        'conversation'  => { 'allowed' => 999_999, 'consumed' => 0 },
        'non_web_inboxes' => { 'allowed' => 999_999, 'consumed' => 0 }
      }
      render json: { id: @account.id, limits: custom_limits }, status: :ok
    end

    def update_quantities
      if @account.id == 1
        render json: { error: 'Conta administrativa nao possui cobranca.' }, status: :unprocessable_entity
        return
      end
      unless AsaasClient.configured?
        render json: { error: 'Sistema de pagamento nao configurado.' }, status: :unprocessable_entity
        return
      end

      new_agents  = params[:agents].to_i
      new_inboxes = params[:inboxes].to_i
      current_agents_used  = farol_billable_agents(@account)
      current_inboxes_used = @account.inboxes.count

      if new_agents < 1
        render json: { error: 'Minimo de 1 usuario (agente).' }, status: :unprocessable_entity
        return
      end
      if new_inboxes < 1
        render json: { error: 'Minimo de 1 conexao (caixa de entrada).' }, status: :unprocessable_entity
        return
      end
      if new_agents < current_agents_used
        render json: { error: "Impossivel reduzir para #{new_agents} agentes. Voce possui #{current_agents_used} em uso." }, status: :unprocessable_entity
        return
      end
      if new_inboxes < current_inboxes_used
        render json: { error: "Impossivel reduzir para #{new_inboxes} conexoes. Voce possui #{current_inboxes_used} em uso." }, status: :unprocessable_entity
        return
      end

      begin
        # Save CPF/CNPJ if provided
        cpf_cnpj = params[:cpf_cnpj].to_s.gsub(/\D/, '')
        if cpf_cnpj.present?
          @account.update!(custom_attributes: @account.custom_attributes.merge('cpf_cnpj' => cpf_cnpj))
        end

        service = Enterprise::Billing::CreateStripeCustomerService.new(account: @account)

        customer_id = @account.custom_attributes['asaas_customer_id']
        if customer_id.blank?
          service.perform
          @account.reload
          customer_id = @account.custom_attributes['asaas_customer_id']
          unless customer_id.present?
            render json: { error: 'Erro ao criar cliente no Asaas.' }, status: :unprocessable_entity
            return
          end
        end

        total_value = (new_agents * AsaasClient.agent_price) + (new_inboxes * AsaasClient.inbox_price)
        sub_id = @account.custom_attributes['asaas_subscription_id']

        if sub_id.present?
          update_body = {
            value: total_value.round(2),
            description: "FarolChat - #{new_agents} Agentes + #{new_inboxes} Conexoes",
            updatePendingPayments: true
          }
          result = AsaasClient.put("/subscriptions/#{sub_id}", update_body)
          unless result[:success]
            error_msg = result[:data]['errors']&.map { |e| e['description'] }&.join(', ') || 'erro desconhecido'
            render json: { error: "Erro ao atualizar assinatura: #{error_msg}" }, status: :unprocessable_entity
            return
          end

          invoice_url = nil
          payments_result = AsaasClient.get("/subscriptions/#{sub_id}/payments?status=PENDING&limit=1")
          if payments_result[:success] && payments_result[:data]['data']&.any?
            invoice_url = payments_result[:data]['data'].first['invoiceUrl']
          end
        else
          sub = service.create_subscription(new_agents, new_inboxes)
          @account.reload
          sub_id = @account.custom_attributes['asaas_subscription_id']
          invoice_url = @account.custom_attributes['hosted_invoice_url']
        end

        @account.update!(
          limits: (@account.limits || {}).merge('agents' => new_agents, 'inboxes' => new_inboxes),
          custom_attributes: @account.custom_attributes.merge(
            'subscribed_quantity' => "#{new_agents} Usuarios . #{new_inboxes} Conexoes",
            'subscribed_agents' => new_agents,
            'subscribed_inboxes' => new_inboxes,
            'subscription_value' => total_value.round(2),
            'hosted_invoice_url' => invoice_url || @account.custom_attributes['hosted_invoice_url']
          )
        )

        Rails.logger.info "BillingPatch: Account #{@account.id} quantities updated: agents=#{new_agents}, inboxes=#{new_inboxes}, total=R$#{total_value.round(2)}"

        render json: {
          success: true,
          message: "Assinatura atualizada! #{new_agents} Agentes . #{new_inboxes} Conexoes - R$ #{format('%.2f', total_value)}/mes",
          agents: { allowed: new_agents, consumed: current_agents_used },
          inboxes: { allowed: new_inboxes, consumed: current_inboxes_used },
          invoice_url: invoice_url,
          subscription_status: 'active'
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "BillingPatch: Error updating quantities for account #{@account.id}: #{e.message}"
        render json: { error: "Erro ao atualizar assinatura: #{e.message}" }, status: :unprocessable_entity
      end
    end
  end

  # Override default_plan? to always return false
  BillingHelper.module_eval do
    def default_plan?(_account)
      false
    end
  end

  # Set plan_name on all accounts that dont have one
  begin
    Account.where.not(id: 1).find_each do |acct|
      lim = acct.limits || {}
      a_count = lim['agents'].to_i
      i_count = lim['inboxes'].to_i
      updates = {}
      updates['plan_name'] = 'Profissional' if acct.custom_attributes['plan_name'].blank?
      updates['subscribed_quantity'] = "#{a_count} Usuarios . #{i_count} Conexoes" if a_count > 0 || i_count > 0
      updates['subscribed_agents'] = a_count if a_count > 0
      updates['subscribed_inboxes'] = i_count if i_count > 0
      acct.update_column(:custom_attributes, acct.custom_attributes.merge(updates)) if updates.any?
    end
    Rails.logger.info 'BillingPatch: Set plan_name + subscribed_quantity on accounts'
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to set plan_name: #{e.message}"
  end

  Rails.logger.info 'BillingPatch: Patched limits + checkout + update_quantities for Asaas'

  # ============================================================================
  # 4b. SuperAdmin: auto-link to all accounts
  # ============================================================================
  begin
    super_admin_ids = User.where(type: 'SuperAdmin').pluck(:id)
    if super_admin_ids.any?
      Account.where.not(id: 1).find_each do |acct|
        super_admin_ids.each do |sa_id|
          AccountUser.find_or_create_by!(account_id: acct.id, user_id: sa_id) { |au| au.role = :administrator } rescue nil
        end
      end
      Rails.logger.info 'BillingPatch: SuperAdmin users linked to all accounts'
    end
  rescue StandardError => e
    Rails.logger.error "BillingPatch: Failed to link SuperAdmin: #{e.message}"
  end

  Account.class_eval do
    after_create :link_super_admins
    private
    def link_super_admins
      return if id == 1
      User.where(type: 'SuperAdmin').find_each do |sa|
        AccountUser.find_or_create_by!(account: self, user: sa) { |au| au.role = :administrator }
      end
    rescue StandardError => e
      Rails.logger.error "BillingPatch: Failed to auto-link SuperAdmin to new account #{id}: #{e.message}"
    end
  end

  Rails.logger.info 'BillingPatch: SuperAdmin auto-link active'

  # ============================================================================
  # 5. Enforce limits
  # ============================================================================
  AccountUser.class_eval do
    validate :check_agent_limit, on: :create
    private
    def check_agent_limit
      return unless account
      acct_limits = account.limits || {}
      max_agents = acct_limits['agents'].to_i
      return if max_agents.zero?
      current_agents = farol_billable_agents(account)
      return unless current_agents >= max_agents
      errors.add(:base, "Limite de agentes atingido (#{max_agents}). Aumente sua assinatura em Configuracoes > Billing.")
    end
  end

  Inbox.class_eval do
    validate :check_inbox_limit, on: :create
    private
    def check_inbox_limit
      return unless account
      acct_limits = account.limits || {}
      max_inboxes = acct_limits['inboxes'].to_i
      return if max_inboxes.zero?
      current_inboxes = account.inboxes.count
      return unless current_inboxes >= max_inboxes
      errors.add(:base, "Limite de caixas de entrada atingido (#{max_inboxes}). Aumente sua assinatura em Configuracoes > Billing.")
    end
  end

  Rails.logger.info 'BillingPatch: Enforcement validators added'

  # ============================================================================
  # 6. Block suspended accounts from sending messages
  # ============================================================================
  SendReplyJob.class_eval do
    original_perform = instance_method(:perform)
    define_method(:perform) do |message_id|
      message = Message.find_by(id: message_id)
      if message&.account&.suspended?
        message.update!(status: :failed, content_attributes: (message.content_attributes || {}).merge('external_error' => 'Conta suspensa por falta de pagamento. Regularize sua assinatura.'))
        return
      end
      original_perform.bind(self).call(message_id)
    end
  end

  Rails.logger.info 'BillingPatch: Suspended account message blocking active'

  # ============================================================================
  # 7. Routes
  # ============================================================================
  Rails.application.routes.append do
    namespace :enterprise, defaults: { format: 'json' } do
      namespace :api do
        namespace :v1 do
          resources :accounts, only: [] do
            member do
              post :update_quantities
              get :billing_config
            end
          end
        end
      end
    end

    post '/webhooks/asaas', to: 'webhooks/asaas#receive'
  end

  AccountPolicy.class_eval do
    def update_quantities?
      @account_user.administrator?
    end
    def billing_config?
      @account_user.administrator?
    end
  end

  Rails.logger.info 'BillingPatch: Routes + policies added'

  # ============================================================================
  # 8. Protect enable_default_features from unknown features
  # ============================================================================
  Featurable.module_eval do
    private

    def enable_default_features
      config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
      return true if config.blank?

      valid_names = Featurable::FEATURE_LIST.pluck('name')
      features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name).select { |n| valid_names.include?(n) }
      enable_features(*features_to_enabled)
    end
  end

  Rails.logger.info 'BillingPatch: Featurable safe enable_default_features patched'
  Rails.logger.info 'BillingPatch: All Asaas billing patches loaded successfully!'
end
