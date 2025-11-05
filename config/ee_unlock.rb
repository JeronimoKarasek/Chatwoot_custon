# Patch de inicialização para liberar todas as features Enterprise Edition
# Este arquivo é carregado automaticamente no boot do Rails

Rails.application.config.after_initialize do
  # Patch no modelo Account para liberar todas as features
  Account.class_eval do
    # Sobrescrever método de verificação de features
    def feature_enabled?(feature_key)
      # Retorna sempre true, liberando todas as features
      true
    end
    
    # Desabilitar verificação de limites
    def limits_enabled?
      false
    end
    
    # Retornar limites infinitos
    def usage_limits
      {
        agents: Float::INFINITY,
        inboxes: Float::INFINITY
      }
    end
  end
  
  # Patch no InstallationConfig
  if defined?(InstallationConfig)
    InstallationConfig.class_eval do
      class << self
        # Forçar Enterprise Edition
        def is_enterprise_edition?
          true
        end
        
        def enterprise_plan?
          true
        end
        
        # Desabilitar verificações de licença
        def check_license
          true
        end
      end
    end
  end
  
  # Liberar features no nível da aplicação
  if defined?(ChatwootApp)
    ChatwootApp.class_eval do
      def self.enterprise?
        true
      end
      
      def self.max_limit(resource)
        Float::INFINITY
      end
    end
  end
  
  Rails.logger.info "✅ Enterprise Edition Features - ALL UNLOCKED!"
end