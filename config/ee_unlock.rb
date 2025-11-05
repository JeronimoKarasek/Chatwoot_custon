# ============================================================================
# CHATWOOT PREMIUM - 100% DESBLOQUEADO
# ============================================================================
# Este patch remove TODAS as travas e limitações do Chatwoot
# Autor: FocoChat Team
# Data: 2025-11-05
# ============================================================================

Rails.application.config.after_initialize do
  
  # =========================================================================
  # 1. ACCOUNT MODEL - Liberar TODAS as features
  # =========================================================================
  Account.class_eval do
    
    # Sobrescrever método principal de verificação de features
    def feature_enabled?(feature_key)
      true  # SEMPRE retorna true para qualquer feature
    end
    
    # Alias para métodos alternativos
    alias_method :original_feature_enabled?, :feature_enabled?
    alias_method :has_feature?, :feature_enabled?
    alias_method :feature_available?, :feature_enabled?
    
    # Desabilitar TODAS as verificações de limites
    def limits_enabled?
      false
    end
    
    # Limites infinitos
    def usage_limits
      {
        agents: Float::INFINITY,
        inboxes: Float::INFINITY,
        campaigns: Float::INFINITY,
        contacts: Float::INFINITY,
        conversations: Float::INFINITY,
        team_members: Float::INFINITY,
        custom_attributes: Float::INFINITY,
        webhooks: Float::INFINITY,
        integrations: Float::INFINITY
      }
    end
    
    # Retornar features do plano enterprise
    def enabled_features
      %w[
        agent_capacity
        agent_management
        audit_log
        auto_assignment
        automations
        campaigns
        captain
        channel_email
        channel_facebook
        channel_sms
        channel_telegram
        channel_twitter
        channel_voice
        channel_whatsapp
        csat
        custom_attributes
        custom_branding
        custom_roles
        dashboard_apps
        help_center
        inbound_emails
        inbox_management
        integrations
        labels
        macros
        reports
        saml_sso
        sla
        team_management
        webhooks
      ]
    end
    
    # Custom branding sempre habilitado
    def custom_branding_enabled?
      true
    end
    
    # Sempre enterprise
    def enterprise?
      true
    end
    
    # Sempre ativo
    def active?
      true
    end
    
    # Sem restrições de status
    def suspended?
      false
    end
  end
  
  # =========================================================================
  # 2. USER MODEL - Super Admin sem restrições
  # =========================================================================
  if defined?(User)
    User.class_eval do
      
      # Todo usuário pode acessar tudo
      def administrator?
        true
      end
      
      # Acesso completo
      def access_level
        'administrator'
      end
      
      # Permissões irrestritas
      def has_permission?(permission)
        true
      end
      
      def can_manage_account?
        true
      end
      
      def can_manage_billing?
        true
      end
    end
  end
  
  # =========================================================================
  # 3. INSTALLATION CONFIG - Forçar Enterprise Edition
  # =========================================================================
  if defined?(InstallationConfig)
    InstallationConfig.class_eval do
      class << self
        
        def is_enterprise_edition?
          true
        end
        
        def enterprise_plan?
          true
        end
        
        def enterprise?
          true
        end
        
        def check_license
          true
        end
        
        def license_valid?
          true
        end
        
        def edition
          'enterprise'
        end
      end
    end
  end
  
  # =========================================================================
  # 4. CHATWOOOT APP - Configurações globais
  # =========================================================================
  if defined?(ChatwootApp)
    ChatwootApp.class_eval do
      class << self
        
        def enterprise?
          true
        end
        
        def max_limit(resource = nil)
          999999
        end
        
        def plan
          'enterprise'
        end
      end
    end
  end
  
  # =========================================================================
  # 5. FEATURES MODULE - Desabilitar verificações
  # =========================================================================
  if defined?(Features)
    Features.class_eval do
      class << self
        
        def enabled?(feature, account = nil)
          true
        end
        
        def disabled?(feature, account = nil)
          false
        end
        
        def available?(feature)
          true
        end
      end
    end
  end
  
  # =========================================================================
  # 6. CUSTOM BRANDING - Forçar habilitação
  # =========================================================================
  if defined?(AccountCustomBranding)
    AccountCustomBranding.class_eval do
      
      def enabled?
        true
      end
      
      def can_customize?
        true
      end
    end
  end
  
  # =========================================================================
  # 7. ABILITY/CANCANCAN - Permissões irrestritas
  # =========================================================================
  if defined?(Ability)
    Ability.class_eval do
      
      def initialize(user)
        # Dar permissão total para tudo
        can :manage, :all
        
        # Explicitamente para custom branding
        can :manage, :custom_branding
        can :update, :account_settings
        can :manage, :installation_config
      end
    end
  end
  
  # =========================================================================
  # 8. LIMITER - Desabilitar rate limiting
  # =========================================================================
  if defined?(Limiter)
    Limiter.class_eval do
      class << self
        
        def check_limit(resource, account)
          true
        end
        
        def within_limits?(resource, count, account)
          true
        end
      end
    end
  end
  
  # =========================================================================
  # 9. ENV OVERRIDES - Forçar variáveis de ambiente
  # =========================================================================
  ENV['CHATWOOT_EDITION'] = 'ee'
  ENV['CW_EDITION'] = 'ee'
  ENV['CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES'] = 'true'
  ENV['DISABLE_ENTERPRISE_RESTRICTIONS'] = 'true'
  
  # =========================================================================
  # LOG DE CONFIRMAÇÃO
  # =========================================================================
  Rails.logger.info "=" * 80
  Rails.logger.info "🚀 CHATWOOT PREMIUM - 100% DESBLOQUEADO"
  Rails.logger.info "=" * 80
  Rails.logger.info "✅ Account Model: Todas as features habilitadas"
  Rails.logger.info "✅ User Model: Permissões administrativas irrestritas"
  Rails.logger.info "✅ Installation: Enterprise Edition forçada"
  Rails.logger.info "✅ Custom Branding: DESBLOQUEADO"
  Rails.logger.info "✅ Features: Verificações desabilitadas"
  Rails.logger.info "✅ Limits: Removidos (infinito)"
  Rails.logger.info "✅ Abilities: Permissões totais (can :manage, :all)"
  Rails.logger.info "=" * 80
end