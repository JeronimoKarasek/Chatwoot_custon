# ============================================================
# FarolChat - Patch: Sistema de Follow-up Automático
# Funcionalidades:
#   1. Configuração de follow-ups por conta (nome, tempo, mensagem)
#   2. Toggle ativar/desativar por conta e por follow-up individual
#   3. Variáveis dinâmicas na mensagem ({{contact.name}}, etc.)
#   4. Disparo automático quando última mensagem é do AGENTE (outgoing)
#     e o cliente não responde dentro do tempo configurado
#   5. Anti-duplicata via follow_up_logs (não reenvia no mesmo ciclo;
#     ciclo reinicia quando cliente envia nova mensagem)
#   6. API REST completa para CRUD + toggle
# Data: 2026-04-18
# ============================================================

Rails.application.config.after_initialize do
  Rails.logger.info '[FarolChat] Carregando patch do sistema de Follow-up...'

  # ============================================================
  # 1. CREATE TABLES (idempotent - IF NOT EXISTS)
  # ============================================================
  begin
    conn = ActiveRecord::Base.connection

    unless conn.table_exists?(:follow_ups)
      conn.execute(<<-SQL)
        CREATE TABLE follow_ups (
          id BIGSERIAL PRIMARY KEY,
          account_id BIGINT NOT NULL,
          name VARCHAR(255) NOT NULL,
          delay_time INTEGER NOT NULL,
          delay_unit INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          active BOOLEAN NOT NULL DEFAULT TRUE,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
          CONSTRAINT fk_follow_ups_account
            FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        CREATE INDEX index_follow_ups_on_account_id ON follow_ups(account_id);
        CREATE INDEX index_follow_ups_on_account_active ON follow_ups(account_id, active);
      SQL
      Rails.logger.info '[FarolChat] Tabela follow_ups criada com sucesso'
    end

    unless conn.table_exists?(:follow_up_logs)
      conn.execute(<<-SQL)
        CREATE TABLE follow_up_logs (
          id BIGSERIAL PRIMARY KEY,
          follow_up_id BIGINT NOT NULL,
          conversation_id BIGINT NOT NULL,
          account_id BIGINT NOT NULL,
          last_message_id BIGINT,
          sent_at TIMESTAMP NOT NULL DEFAULT NOW(),
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
          CONSTRAINT fk_fu_logs_follow_up
            FOREIGN KEY (follow_up_id) REFERENCES follow_ups(id) ON DELETE CASCADE,
          CONSTRAINT fk_fu_logs_conversation
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          CONSTRAINT fk_fu_logs_account
            FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        CREATE INDEX idx_fu_logs_lookup
          ON follow_up_logs(follow_up_id, conversation_id, last_message_id);
        CREATE INDEX idx_fu_logs_account
          ON follow_up_logs(account_id);
      SQL
      Rails.logger.info '[FarolChat] Tabela follow_up_logs criada com sucesso'
    end

    # Add columns for label exclusion, time window, and add label on send
    unless conn.column_exists?(:follow_ups, :excluded_labels)
      conn.execute("ALTER TABLE follow_ups ADD COLUMN excluded_labels JSONB DEFAULT '[]'::jsonb")
      Rails.logger.info '[FarolChat] Coluna excluded_labels adicionada'
    end
    unless conn.column_exists?(:follow_ups, :exclude_no_label)
      conn.execute("ALTER TABLE follow_ups ADD COLUMN exclude_no_label BOOLEAN DEFAULT FALSE")
      Rails.logger.info '[FarolChat] Coluna exclude_no_label adicionada'
    end
    unless conn.column_exists?(:follow_ups, :schedule_start_hour)
      conn.execute("ALTER TABLE follow_ups ADD COLUMN schedule_start_hour INTEGER")
      Rails.logger.info '[FarolChat] Coluna schedule_start_hour adicionada'
    end
    unless conn.column_exists?(:follow_ups, :schedule_end_hour)
      conn.execute("ALTER TABLE follow_ups ADD COLUMN schedule_end_hour INTEGER")
      Rails.logger.info '[FarolChat] Coluna schedule_end_hour adicionada'
    end
    unless conn.column_exists?(:follow_ups, :add_label_on_send)
      conn.execute("ALTER TABLE follow_ups ADD COLUMN add_label_on_send VARCHAR(255)")
      Rails.logger.info '[FarolChat] Coluna add_label_on_send adicionada'
    end
  rescue => e
    Rails.logger.error "[FarolChat] Erro ao criar tabelas follow-up: #{e.message}"
  end

  # ============================================================
  # 2. DEFINE MODELS
  # ============================================================
  Object.send(:remove_const, :FollowUp) if defined?(::FollowUp)
  Object.send(:remove_const, :FollowUpLog) if defined?(::FollowUpLog)

  class ::FollowUp < ApplicationRecord
    self.table_name = 'follow_ups'

    belongs_to :account
    has_many :follow_up_logs, dependent: :destroy

    enum delay_unit: { minutes: 0, hours: 1 }

    validates :name, presence: true
    validates :delay_time, presence: true, numericality: { greater_than: 0 }
    validates :message, presence: true
    validates :account_id, presence: true

    scope :active, -> { where(active: true) }

    def delay_in_seconds
      case delay_unit
      when 'minutes' then delay_time * 60
      when 'hours' then delay_time * 3600
      else delay_time * 60
      end
    end
  end

  class ::FollowUpLog < ApplicationRecord
    self.table_name = 'follow_up_logs'

    belongs_to :follow_up
    belongs_to :conversation
    belongs_to :account
  end

  # ============================================================
  # 3. EXTEND ACCOUNT MODEL
  # ============================================================
  Account.class_eval do
    has_many :follow_ups, dependent: :destroy unless reflect_on_association(:follow_ups)
  end

  # ============================================================
  # 4. DEFINE SERVICE
  # ============================================================
  module ::FollowUps; end unless defined?(::FollowUps)

  # Service que substitui variáveis e envia a mensagem
  svc_klass = Class.new do
    def initialize(follow_up:, conversation:, last_message:)
      @follow_up = follow_up
      @conversation = conversation
      @last_message = last_message
    end

    def perform
      processed = process_variables(@follow_up.message, @conversation)

      message = @conversation.messages.create!(
        message_type: :outgoing,
        content: processed,
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
        content_type: :text
      )

      ::FollowUpLog.create!(
        follow_up_id: @follow_up.id,
        conversation_id: @conversation.id,
        account_id: @conversation.account_id,
        last_message_id: @last_message.id,
        sent_at: Time.current
      )

      # Add label to conversation if configured
      if @follow_up.add_label_on_send.present?
        begin
          labels = @conversation.label_list.to_a
          unless labels.include?(@follow_up.add_label_on_send)
            @conversation.label_list.add(@follow_up.add_label_on_send)
            @conversation.save!
            Rails.logger.info "[FarolChat] Label '#{@follow_up.add_label_on_send}' adicionada → conversa ##{@conversation.display_id}"
          end
        rescue => e
          Rails.logger.error "[FarolChat] Erro ao adicionar label: #{e.message}"
        end
      end

      Rails.logger.info(
        "[FarolChat] Follow-up '#{@follow_up.name}' enviado → " \
        "conversa ##{@conversation.display_id} (account #{@conversation.account_id})"
      )
      message
    rescue => e
      Rails.logger.error "[FarolChat] Erro ao enviar follow-up #{@follow_up.id}: #{e.message}"
      nil
    end

    private

    def process_variables(template, conversation)
      contact = conversation.contact
      result = template.dup

      if contact
        result.gsub!('{{contact.name}}', contact.name.to_s)
        result.gsub!('{{contact.first_name}}', contact.name.to_s.split(' ').first.to_s)
        result.gsub!('{{contact.last_name}}', (contact.try(:last_name) || contact.name.to_s.split(' ')[1..].to_a.join(' ')).to_s)
        result.gsub!('{{contact.email}}', contact.email.to_s)
        result.gsub!('{{contact.phone_number}}', contact.phone_number.to_s)
        result.gsub!('{{contact.identifier}}', contact.identifier.to_s)
      end

      result.gsub!('{{conversation.id}}', @conversation.display_id.to_s)
      result
    end
  end

  FollowUps.const_set(:MessageSenderService, svc_klass) unless FollowUps.const_defined?(:MessageSenderService)

  # ============================================================
  # 5. DEFINE JOBS
  # ============================================================

  # Cron Worker: Sidekiq worker puro registrado via sidekiq-cron
  # Roda a cada 1 minuto, itera contas com follow-up ativado
  unless defined?(::FollowUpCronWorker)
    class ::FollowUpCronWorker
      include Sidekiq::Job
      sidekiq_options queue: 'scheduled_jobs'

      def perform
        Account.where(
          "settings IS NOT NULL AND (settings->>'follow_up_enabled') = 'true'"
        ).find_each(batch_size: 100) do |account|
          next unless account.follow_ups.active.exists?

          ::FollowUpProcessAccountWorker.perform_async(account.id)
        end
      rescue => e
        Rails.logger.error "[FarolChat] Erro no FollowUp cron: #{e.message}"
      end
    end
  end

  # Worker Processor: para cada follow-up ativo da conta, busca conversas elegíveis
  unless defined?(::FollowUpProcessAccountWorker)
    class ::FollowUpProcessAccountWorker
      include Sidekiq::Job
      sidekiq_options queue: 'scheduled_jobs'

      def perform(account_id)
        account = Account.find_by(id: account_id)
        return unless account

        account.follow_ups.active.find_each do |follow_up|
          process_follow_up(account, follow_up)
        end
      rescue => e
        Rails.logger.error "[FarolChat] Erro ao processar follow-ups conta #{account_id}: #{e.message}"
      end

      private

      def process_follow_up(account, follow_up)
        # Check time window (horário de Brasília)
        if follow_up.schedule_start_hour.present? && follow_up.schedule_end_hour.present?
          current_hour = Time.current.in_time_zone('America/Sao_Paulo').hour
          start_h = follow_up.schedule_start_hour
          end_h = follow_up.schedule_end_hour
          in_window = if start_h <= end_h
                        current_hour >= start_h && current_hour < end_h
                      else
                        current_hour >= start_h || current_hour < end_h
                      end
          unless in_window
            Rails.logger.info(
              "[FarolChat] Follow-up '#{follow_up.name}': fora do horário " \
              "(#{current_hour}h BRT, janela #{start_h}h-#{end_h}h)"
            )
            return
          end
        end

        delay = follow_up.delay_in_seconds
        threshold = Time.current - delay

        # Margem de segurança: só envia follow-up se a última msg outgoing
        # foi enviada entre [delay] e [delay + margem] atrás.
        # Exemplo: follow-up de 5 min → só conversas com última msg entre 5 e 7 min atrás.
        # Margem = max(2 minutos, 40% do delay)
        # Isso evita enviar para conversas antigas que passaram do ponto.
        margin = [120, (delay * 0.4).to_i].max
        max_age = Time.current - delay - margin

        Rails.logger.info(
          "[FarolChat] Follow-up '#{follow_up.name}': delay=#{delay}s margin=#{margin}s " \
          "janela=#{max_age.utc.strftime('%H:%M:%S')}..#{threshold.utc.strftime('%H:%M:%S')}"
        )

        sql = ActiveRecord::Base.sanitize_sql_array([<<-SQL.squish, account.id, account.id, threshold.utc, max_age.utc])
          SELECT sub.conversation_id, sub.last_message_id
          FROM (
            SELECT DISTINCT ON (m.conversation_id)
              m.conversation_id,
              m.id AS last_message_id,
              m.message_type,
              m.created_at AS msg_created_at
            FROM messages m
            INNER JOIN conversations c
              ON c.id = m.conversation_id
              AND c.account_id = m.account_id
            WHERE m.account_id = ?
              AND c.status = 0
              AND m.message_type IN (0, 1, 3)
              AND m.private = false
            ORDER BY m.conversation_id, m.created_at DESC
          ) sub
          WHERE sub.message_type = 1
            AND sub.conversation_id IN (
              SELECT id FROM conversations
              WHERE account_id = ? AND status = 0
            )
            AND sub.msg_created_at < ?
            AND sub.msg_created_at > ?
        SQL

        results = ActiveRecord::Base.connection.execute(sql)

        results.each do |row|
          conversation_id = row['conversation_id'].to_i
          last_message_id = row['last_message_id'].to_i

          last_incoming_at = Message.where(
            conversation_id: conversation_id,
            message_type: :incoming,
            private: false
          ).maximum(:created_at) || Time.at(0)

          already_sent = ::FollowUpLog.where(
            follow_up_id: follow_up.id,
            conversation_id: conversation_id
          ).where('created_at > ?', last_incoming_at).exists?
          next if already_sent

          conversation = Conversation.find_by(id: conversation_id)
          next unless conversation

          # Label exclusion checks
          excluded = follow_up.excluded_labels
          excluded = excluded.is_a?(Array) ? excluded : []
          if excluded.any? || follow_up.exclude_no_label
            conv_labels = conversation.label_list.to_a
            next if excluded.any? && conv_labels.any? { |l| excluded.include?(l) }
            next if follow_up.exclude_no_label && conv_labels.empty?
          end

          last_message = Message.find_by(id: last_message_id)
          next unless last_message

          ::FollowUps::MessageSenderService.new(
            follow_up: follow_up,
            conversation: conversation,
            last_message: last_message
          ).perform
        end
      rescue => e
        Rails.logger.error "[FarolChat] Erro no follow-up #{follow_up.id}: #{e.message}"
      end
    end
  end

  # ============================================================
  # 6. REGISTER INDEPENDENT CRON JOB (sidekiq-cron)
  # ============================================================
  begin
    require 'sidekiq-cron'
    Sidekiq::Cron::Job.create(
      name: 'follow_up_trigger_scheduler',
      cron: '*/1 * * * *',
      class: 'FollowUpCronWorker'
    )
    Rails.logger.info '[FarolChat] Cron job follow_up_trigger_scheduler registrado (a cada 1 min)'
  rescue => e
    Rails.logger.error "[FarolChat] Erro ao registrar cron follow-up: #{e.message}"
  end

  # ============================================================
  # 7. DEFINE CONTROLLER
  # ============================================================
  ctrl_klass = Class.new(Api::V1::Accounts::BaseController) do

    before_action :check_admin_access
    before_action :find_follow_up, only: [:show, :update, :destroy]

    def index
      follow_ups = Current.account.follow_ups.order(created_at: :desc)
      enabled = Current.account.settings.is_a?(Hash) &&
                Current.account.settings['follow_up_enabled'] == true

      render json: {
        data: follow_ups.map { |fu| serialize_follow_up(fu) },
        enabled: enabled
      }
    end

    def create
      follow_up = Current.account.follow_ups.new(follow_up_params)

      if follow_up.save
        render json: { data: serialize_follow_up(follow_up) }, status: :created
      else
        render json: { errors: follow_up.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
      render json: { data: serialize_follow_up(@follow_up) }
    end

    def update
      if @follow_up.update(follow_up_params)
        render json: { data: serialize_follow_up(@follow_up) }
      else
        render json: { errors: @follow_up.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @follow_up.destroy!
      head :no_content
    end

    # POST /api/v1/accounts/:account_id/follow_ups/toggle
    def toggle
      settings = Current.account.settings || {}
      current_val = settings['follow_up_enabled'] == true
      new_val = !current_val
      settings['follow_up_enabled'] = new_val
      # Salvar timestamp de ativação para evitar processar conversas antigas
      settings['follow_up_enabled_at'] = Time.current.utc.iso8601 if new_val
      Current.account.update!(settings: settings)

      render json: { enabled: new_val }
    end

    private

    def check_admin_access
      unless Current.account_user&.administrator?
        render json: { error: 'Não autorizado' }, status: :unauthorized
      end
    end

    def find_follow_up
      @follow_up = Current.account.follow_ups.find(params[:id])
    end

    def follow_up_params
      params.permit(:name, :delay_time, :delay_unit, :message, :active,
                     :exclude_no_label, :schedule_start_hour, :schedule_end_hour,
                     :add_label_on_send, excluded_labels: [])
    end

    def serialize_follow_up(fu)
      {
        id: fu.id,
        name: fu.name,
        delay_time: fu.delay_time,
        delay_unit: fu.delay_unit,
        message: fu.message,
        active: fu.active,
        excluded_labels: fu.excluded_labels || [],
        exclude_no_label: fu.exclude_no_label || false,
        schedule_start_hour: fu.schedule_start_hour,
        schedule_end_hour: fu.schedule_end_hour,
        add_label_on_send: fu.add_label_on_send,
        created_at: fu.created_at.iso8601,
        updated_at: fu.updated_at.iso8601
      }
    end
  end

  unless Api::V1::Accounts.const_defined?(:FollowUpsController)
    Api::V1::Accounts.const_set(:FollowUpsController, ctrl_klass)
  end

  # ============================================================
  # 8. ADD ROUTES
  # ============================================================
  Rails.application.routes.append do
    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        resources :accounts, only: [] do
          scope module: :accounts do
            resources :follow_ups, only: [:index, :create, :show, :update, :destroy]
            post 'follow_ups/toggle', to: 'follow_ups#toggle', as: :follow_ups_toggle
          end
        end
      end
    end
  end

  Rails.logger.info '[FarolChat] ✅ Patch do sistema de Follow-up carregado com sucesso!'
end
