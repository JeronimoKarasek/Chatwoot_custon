# frozen_string_literal: true

# Disable Internal::CheckNewVersionsJob - it causes Sidekiq shutdown loops
# This job incorrectly calls Puma shutdown code from within Sidekiq workers

Rails.application.config.after_initialize do
  if defined?(Internal::CheckNewVersionsJob)
    Internal::CheckNewVersionsJob.class_eval do
      def perform
        Rails.logger.info "CheckNewVersionsJob: DISABLED - skipping version check"
        # Do nothing - this job causes Sidekiq to crash
      end
    end
    Rails.logger.info "CheckNewVersionsJob: Patched to do nothing"
  end

  # Also disable Enterprise version if exists
  if defined?(Enterprise::Internal::CheckNewVersionsJob)
    Enterprise::Internal::CheckNewVersionsJob.class_eval do
      def perform
        Rails.logger.info "Enterprise::CheckNewVersionsJob: DISABLED - skipping version check"
        # Do nothing
      end
    end
    Rails.logger.info "Enterprise::CheckNewVersionsJob: Patched to do nothing"
  end
end
