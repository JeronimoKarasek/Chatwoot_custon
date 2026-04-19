# frozen_string_literal: true
# Evolution API Routes - loaded after Rails initialization

Rails.application.config.after_initialize do
  Rails.application.routes.append do
    # Webhook routes for receiving messages from Evolution
    namespace :webhooks do
      post 'evolution/:instance_name', to: 'evolution#process_payload', as: :evolution_webhook
      get 'evolution/:instance_name', to: 'evolution#process_payload'
    end
    
    # API routes for Evolution instance management
    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        namespace :accounts do
          scope ':account_id' do
            namespace :evolution do
              resources :authorizations, only: [:create]
              get 'status', to: 'authorizations#status'
            end
          end
        end
      end
    end
  end
end
