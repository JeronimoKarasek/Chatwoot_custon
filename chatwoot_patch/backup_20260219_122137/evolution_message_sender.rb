# frozen_string_literal: true
# Evolution Message Sender - DISABLED
# Evolution API should use Channel::Api, not Channel::Whatsapp

Rails.application.config.after_initialize do
  Rails.logger.info "Evolution Message Sender: DISABLED - Use Channel::Api for Evolution connections"
end
