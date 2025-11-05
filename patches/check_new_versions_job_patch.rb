# Disable or harden Internal::CheckNewVersionsJob to avoid 500s
Rails.application.config.after_initialize do
  if defined?(Internal::CheckNewVersionsJob)
    Internal::CheckNewVersionsJob.class_eval do
      def perform(*args)
        Rails.logger.info 'ℹ️ Internal::CheckNewVersionsJob disabled by custom build to prevent 500s'
        # no-op
      end
    end
  end
end
