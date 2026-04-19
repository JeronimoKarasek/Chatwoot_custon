# ============================================================
# FarolChat - Patch: Sistema de Envio em Massa para Campanhas
# Funcionalidades:
#   1. Suporte a etiquetas de conversa (além das de contato)
#   2. Importação de base CSV com criação automática de contatos
#   3. Controle de velocidade: Normal (20/s), Lento (1/s), Humano (6/min)
#   4. Execução manual com barra de progresso via ActionCable
# Data: 2026-04-18
# ============================================================

Rails.application.config.after_initialize do
  Rails.logger.info '[FarolChat] Carregando patch de envio em massa para campanhas...'

  # ============================================================
  # 1. EXTEND CAMPAIGN MODEL
  # ============================================================
  Campaign.class_eval do
    enum sending_speed: { normal: 0, slow: 1, human: 2 }, _prefix: :speed
    enum audience_type: { contact_labels: 0, conversation_labels: 1, csv_import: 2 }, _prefix: :audience

    # Fix: validate_url crashes when trigger_rules is nil (one_off campaigns)
    def validate_url
      return if trigger_rules.blank?
      return unless trigger_rules['url']

      use_http_protocol = trigger_rules['url'].starts_with?('http://') || trigger_rules['url'].starts_with?('https://')
      errors.add(:url, 'invalid') if inbox&.inbox_type == 'Website' && !use_http_protocol
    end

    # Override trigger! to use mass send for campaigns with sending_speed
    def trigger!
      return unless one_off?
      return if completed?

      if sending_speed.present? && inbox&.inbox_type == 'Whatsapp'
        trigger_mass_send!
      else
        execute_campaign
      end
    end

    def trigger_mass_send!
      contacts = resolve_contacts
      total = contacts.count

      if total.zero?
        Rails.logger.warn "[FarolChat] Campanha agendada #{id} sem contatos"
        return
      end

      contact_ids = contacts.pluck(:id)

      update_progress!(
        'total' => total,
        'sent' => 0,
        'failed' => 0,
        'status' => 'running'
      )

      Campaigns::MassSendBatchJob.perform_async(id, contact_ids, 0)
      Rails.logger.info "[FarolChat] Campanha agendada #{id} iniciada com #{total} contatos"
    end

    def progress_data
      (progress.presence || { 'total' => 0, 'sent' => 0, 'failed' => 0, 'status' => 'pending' }).with_indifferent_access
    end

    def update_progress!(updates)
      current = progress_data
      current.merge!(updates.stringify_keys)
      update_column(:progress, current)
      broadcast_progress!
    end

    def broadcast_progress!
      data = progress_data
      ActionCable.server.broadcast(
        "account_#{account_id}",
        {
          event: 'campaign.progress',
          data: {
            campaign_id: display_id,
            total: data['total'].to_i,
            sent: data['sent'].to_i,
            failed: data['failed'].to_i,
            status: data['status']
          }
        }
      )
    end

    def resolve_contacts
      case audience_type
      when 'conversation_labels'
        resolve_contacts_from_conversation_labels
      when 'csv_import'
        resolve_contacts_from_csv
      else
        resolve_contacts_from_contact_labels
      end
    end

    private

    def resolve_contacts_from_contact_labels
      audience_label_ids = (audience || []).select { |a| a['type'] == 'Label' }.pluck('id')
      label_titles = account.labels.where(id: audience_label_ids).pluck(:title)
      return Contact.none if label_titles.blank?

      account.contacts.tagged_with(label_titles, any: true).where.not(phone_number: [nil, ''])
    end

    def resolve_contacts_from_conversation_labels
      audience_label_ids = (audience || []).select { |a| a['type'] == 'Label' }.pluck('id')
      label_titles = account.labels.where(id: audience_label_ids).pluck(:title)
      return Contact.none if label_titles.blank?

      contact_ids = account.conversations.tagged_with(label_titles, any: true).pluck(:contact_id).uniq
      account.contacts.where(id: contact_ids).where.not(phone_number: [nil, ''])
    end

    def resolve_contacts_from_csv
      ids = csv_contact_ids.is_a?(Array) ? csv_contact_ids : []
      return Contact.none if ids.blank?

      account.contacts.where(id: ids).where.not(phone_number: [nil, ''])
    end
  end

  # ============================================================
  # 2. EXTEND CAMPAIGNS CONTROLLER
  # ============================================================
  Api::V1::Accounts::CampaignsController.class_eval do
    # Override campaign_params to include new fields
    private

    def campaign_params
      permitted = params.require(:campaign).permit(
        :title, :description, :message, :enabled,
        :trigger_only_during_business_hours, :inbox_id, :sender_id,
        :scheduled_at, :sending_speed, :audience_type,
        audience: [:type, :id],
        trigger_rules: {},
        csv_contact_ids: []
      )
      # Allow deeply nested template_params (processed_params.body.1, etc.)
      if params[:campaign][:template_params].present?
        permitted[:template_params] = params[:campaign][:template_params].to_unsafe_h
      end
      permitted
    end

    public

    # POST /api/v1/accounts/:account_id/campaigns/:id/import_csv
    def import_csv
      @campaign = Current.account.campaigns.find_by!(display_id: params[:id])
      authorize(@campaign, :update?)

      file = params[:file]
      return render json: { error: 'Arquivo CSV é obrigatório' }, status: :unprocessable_entity unless file.present?

      result = process_csv_import(file)
      render json: result, status: :ok
    rescue StandardError => e
      Rails.logger.error "[FarolChat] Erro ao importar CSV: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/v1/accounts/:account_id/campaigns/:id/execute
    def execute
      @campaign = Current.account.campaigns.find_by!(display_id: params[:id])
      authorize(@campaign, :update?)

      if @campaign.progress_data['status'] == 'running'
        return render json: { error: 'Campanha já está em execução' }, status: :unprocessable_entity
      end

      if @campaign.completed?
        return render json: { error: 'Campanha já foi concluída' }, status: :unprocessable_entity
      end

      contacts = @campaign.resolve_contacts
      total = contacts.count

      if total.zero?
        return render json: { error: 'Nenhum contato encontrado para esta campanha' }, status: :unprocessable_entity
      end

      contact_ids = contacts.pluck(:id)

      @campaign.update_progress!(
        'total' => total,
        'sent' => 0,
        'failed' => 0,
        'status' => 'running'
      )

      # Enqueue the batch job
      Campaigns::MassSendBatchJob.perform_async(@campaign.id, contact_ids, 0)

      render json: {
        message: 'Campanha iniciada com sucesso',
        progress: @campaign.progress_data
      }, status: :ok
    end

    # GET /api/v1/accounts/:account_id/campaigns/:id/progress
    def get_progress
      @campaign = Current.account.campaigns.find_by!(display_id: params[:id])
      authorize(@campaign, :show?)

      render json: { progress: @campaign.progress_data }, status: :ok
    end

    # GET /api/v1/accounts/:account_id/campaigns/:id/report
    def report
      @campaign = Current.account.campaigns.find_by!(display_id: params[:id])
      authorize(@campaign, :show?)

      progress = @campaign.read_attribute(:progress) || {}
      send_logs = progress['send_logs'] || []

      render json: {
        campaign_id: @campaign.display_id,
        title: @campaign.title,
        total: progress['total'].to_i,
        sent: progress['sent'].to_i,
        failed: progress['failed'].to_i,
        status: progress['status'] || 'pending',
        send_logs: send_logs
      }, status: :ok
    end

    private

    def process_csv_import(file)
      require 'csv'

      content = file.read.force_encoding('UTF-8')
      # Handle BOM
      content = content.sub("\xEF\xBB\xBF", '')

      # Try to detect separator
      separator = content.lines.first&.include?(';') ? ';' : ','

      csv = CSV.parse(content, headers: true, col_sep: separator, liberal_parsing: true)

      # Normalize headers
      headers = csv.headers.map { |h| h&.strip&.downcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/, '')&.gsub(/\s+/, '_') }

      # Map columns
      name_col = headers.index { |h| h =~ /^nome/ }
      phone_col = headers.index { |h| h =~ /^(telefone|phone|celular|numero|whatsapp)/ }
      email_col = headers.index { |h| h =~ /^(email|e-mail|e_mail)/ }
      label_col = headers.index { |h| h =~ /^(etiqueta|label|tag)/ }
      company_col = headers.index { |h| h =~ /^(empresa|company)/ }

      unless name_col && phone_col
        raise 'CSV deve conter as colunas obrigatórias: nome, telefone'
      end

      created = 0
      existing = 0
      errors_count = 0
      contact_ids = []

      csv.each_with_index do |row, idx|
        values = row.fields
        name = values[name_col]&.strip
        phone = normalize_phone(values[phone_col]&.strip)
        email = email_col ? values[email_col]&.strip : nil
        label = label_col ? values[label_col]&.strip : nil
        company_name = company_col ? values[company_col]&.strip : nil

        next if name.blank? || phone.blank?

        begin
          # Try to find existing contact by normalized phone or variants
          # phone is already normalized to +55XXXXXXXXXXX
          phone_without_plus = phone.sub(/^\+/, '')        # 5519971069771
          phone_local = phone.sub(/^\+55/, '')              # 19971069771
          contact = Current.account.contacts.where(
            'phone_number IN (?)', [phone, phone_without_plus, "+#{phone_without_plus}", phone_local, "+#{phone_local}"]
          ).first

          if contact
            existing += 1
          else
            contact = Current.account.contacts.create!(
              name: name,
              phone_number: phone,
              email: email.presence
            )
            created += 1
          end

          # Update company if provided
          if company_name.present? && contact.company_name.blank?
            contact.update(company_name: company_name) rescue nil
          end

          # Apply label if provided
          if label.present?
            existing_labels = contact.label_list || []
            unless existing_labels.include?(label)
              contact.update!(label_list: existing_labels + [label])
            end
          end

          contact_ids << contact.id
        rescue StandardError => e
          Rails.logger.warn "[FarolChat] Erro ao processar linha #{idx + 2} do CSV: #{e.message}"
          errors_count += 1
        end
      end

      # Save contact IDs to campaign
      @campaign.update!(csv_contact_ids: contact_ids.uniq)

      {
        total: csv.length,
        created: created,
        existing: existing,
        errors: errors_count,
        contacts_count: contact_ids.uniq.length
      }
    end

    def normalize_phone(phone)
      return nil if phone.blank?

      # Remove all non-digit characters
      digits = phone.gsub(/\D/, '')

      # Add +55 if Brazilian number without country code
      if digits.length == 10 || digits.length == 11
        "+55#{digits}"
      elsif digits.length == 12 || digits.length == 13
        "+#{digits}"
      elsif digits.start_with?('55') && (digits.length == 12 || digits.length == 13)
        "+#{digits}"
      else
        "+#{digits}"
      end
    end
  end

  # ============================================================
  # 3. EXTEND CAMPAIGN POLICY
  # ============================================================
  CampaignPolicy.class_eval do
    def import_csv?
      @account_user.administrator?
    end

    def execute?
      @account_user.administrator?
    end

    def get_progress?
      @account_user.administrator?
    end
  end

  # ============================================================
  # 4. ADD ROUTES
  # ============================================================
  Rails.application.routes.draw do
    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        resources :accounts, only: [] do
          resources :campaigns, only: [] do
            member do
              post :import_csv
              post :execute
              get :progress, action: :get_progress
            end
          end
        end
      end
    end
  end

  # ============================================================
  # 5. DEFINE MASS SEND BATCH JOB (Sidekiq)
  # ============================================================
  module Campaigns
    class MassSendBatchJob
      include Sidekiq::Job
      sidekiq_options queue: :low, retry: 2

      def perform(campaign_id, contact_ids, offset)
        campaign = Campaign.find_by(id: campaign_id)
        return unless campaign
        return if campaign.progress_data['status'] == 'cancelled'

        # Determine batch size based on sending speed
        batch_size = case campaign.sending_speed
                     when 'normal' then 20
                     when 'slow' then 1
                     when 'human' then 1
                     else 20
                     end

        # Determine delay for next batch
        delay = case campaign.sending_speed
                when 'normal' then 1  # 1 second (20 per second)
                when 'slow' then 1    # 1 second (1 per second)
                when 'human' then 10  # 10 seconds (6 per minute)
                else 1
                end

        # Get current batch
        current_batch_ids = contact_ids[offset, batch_size] || []

        if current_batch_ids.empty?
          # All contacts processed
          campaign.update_progress!('status' => 'completed')
          campaign.completed! unless campaign.completed?
          Rails.logger.info "[FarolChat] Campanha #{campaign.id} concluída"
          return
        end

        sent = campaign.progress_data['sent'].to_i
        failed = campaign.progress_data['failed'].to_i

        contacts = campaign.account.contacts.where(id: current_batch_ids)
        contacts.each do |contact|
          begin
            send_template_to_contact(campaign, contact)
            sent += 1
            append_send_log(campaign, contact, 'sent', nil)
          rescue StandardError => e
            failed += 1
            append_send_log(campaign, contact, 'failed', e.message)
            Rails.logger.error "[FarolChat] Erro ao enviar para #{contact.phone_number}: #{e.message}"
          end
        end

        # Update progress
        campaign.update_progress!(
          'sent' => sent,
          'failed' => failed,
          'status' => 'running'
        )

        # Schedule next batch
        next_offset = offset + batch_size
        if next_offset < contact_ids.length
          Campaigns::MassSendBatchJob.perform_in(delay.seconds, campaign_id, contact_ids, next_offset)
        else
          campaign.update_progress!('status' => 'completed')
          campaign.completed! unless campaign.completed?
          Rails.logger.info "[FarolChat] Campanha #{campaign.id} concluída - #{sent} enviados, #{failed} falhas"
        end
      end

      private

      def send_template_to_contact(campaign, contact)
        return if contact.phone_number.blank?
        return if campaign.template_params.blank?

        inbox = campaign.inbox
        channel = inbox.channel

        # Deep clone template_params and resolve contact variables
        personalized_params = resolve_contact_variables(campaign.template_params.deep_dup, contact)

        processor = Whatsapp::TemplateProcessorService.new(
          channel: channel,
          template_params: personalized_params
        )

        name, namespace, lang_code, processed_parameters = processor.call
        return if name.blank?

        channel.send_template(contact.phone_number, {
          name: name,
          namespace: namespace,
          lang_code: lang_code,
          parameters: processed_parameters
        }, nil)
      end

      def append_send_log(campaign, contact, status, error)
        log_entry = {
          'contact_id' => contact.id,
          'name' => contact.name.to_s,
          'phone' => contact.phone_number.to_s,
          'status' => status,
          'error' => error,
          'at' => Time.current.iso8601
        }
        current_progress = campaign.read_attribute(:progress) || {}
        logs = current_progress['send_logs'] || []
        logs << log_entry
        current_progress['send_logs'] = logs
        campaign.update_column(:progress, current_progress)
      rescue StandardError => e
        Rails.logger.warn "[FarolChat] Erro ao salvar log de envio: #{e.message}"
      end

      def resolve_contact_variables(params, contact)
        contact_data = {
          'contact.name' => contact.name.to_s,
          'contact.phone_number' => contact.phone_number.to_s,
          'contact.email' => contact.email.to_s,
          'contact.company_name' => (contact.try(:company_name) || contact.try(:company) || '').to_s,
          'contact.city' => (contact.try(:city) || contact.additional_attributes&.dig('city') || '').to_s,
          'contact.country' => (contact.try(:country) || contact.additional_attributes&.dig('country') || '').to_s,
        }

        # Replace in processed_params body variables
        if params['processed_params'].is_a?(Hash) && params['processed_params']['body'].is_a?(Hash)
          params['processed_params']['body'].each do |key, value|
            next unless value.is_a?(String)
            contact_data.each do |placeholder, replacement|
              value = value.gsub("{{#{placeholder}}}", replacement)
            end
            params['processed_params']['body'][key] = value
          end
        end

        # Also replace in message text
        if params['message'].is_a?(String)
          contact_data.each do |placeholder, replacement|
            params['message'] = params['message'].gsub("{{#{placeholder}}}", replacement)
          end
        end

        params
      end
    end
  end

  # ============================================================
  # 6. EXTEND JSON BUILDER (via monkey-patch on render)
  # ============================================================
  # We override the jbuilder partial to include new fields
  # This is done by prepending a module to the controller
  Api::V1::Accounts::CampaignsController.class_eval do
    after_action :append_mass_sending_fields, only: [:show, :create, :update]

    private

    def append_mass_sending_fields
      return unless response.content_type&.include?('json')
      return unless @campaign.present?

      begin
        body = JSON.parse(response.body)
        body['sending_speed'] = @campaign.sending_speed
        body['audience_type'] = @campaign.audience_type
        body['csv_contact_ids'] = @campaign.csv_contact_ids
        body['progress'] = @campaign.progress_data
        response.body = body.to_json
      rescue StandardError => e
        Rails.logger.warn "[FarolChat] Erro ao adicionar campos de envio em massa: #{e.message}"
      end
    end
  end

  # Also extend the index action to include new fields
  Api::V1::Accounts::CampaignsController.class_eval do
    after_action :append_mass_sending_fields_to_index, only: [:index]

    private

    def append_mass_sending_fields_to_index
      return unless response.content_type&.include?('json')

      begin
        body = JSON.parse(response.body)
        if body.is_a?(Array)
          campaigns_by_display_id = Current.account.campaigns.index_by(&:display_id)
          body.each do |campaign_json|
            campaign = campaigns_by_display_id[campaign_json['id']]
            next unless campaign

            campaign_json['sending_speed'] = campaign.sending_speed
            campaign_json['audience_type'] = campaign.audience_type
            campaign_json['csv_contact_ids'] = campaign.csv_contact_ids
            campaign_json['progress'] = campaign.progress_data
          end
          response.body = body.to_json
        end
      rescue StandardError => e
        Rails.logger.warn "[FarolChat] Erro ao adicionar campos no index: #{e.message}"
      end
    end
  end

  # Dispatch custom actions via query param on existing show/update routes
  Api::V1::Accounts::CampaignsController.class_eval do
    around_action :handle_mass_sending_action, only: [:show, :update]

    private

    def handle_mass_sending_action
      mass_action = params[:mass_action]
      if mass_action.present?
        case mass_action
        when 'execute'
          execute
        when 'import_csv'
          import_csv
        when 'progress'
          get_progress
        when 'report'
          report
        else
          yield
        end
      else
        yield
      end
    end
  end

  Rails.logger.info '[FarolChat] Patch de envio em massa carregado com sucesso!'
end
