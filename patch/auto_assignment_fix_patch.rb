# frozen_string_literal: true

# AutoAssignmentFixPatch
# Fixes race condition where AssignmentJob runs before the DB transaction commits.
# The original code uses after_save which fires inside the transaction.
# Sidekiq may pick up the job before the transaction commits, causing the job
# to not find the new conversation in the database.
#
# Fix: Override run_auto_assignment to add a 3-second delay to the job,
# giving the transaction time to commit before the job executes.

Rails.application.config.after_initialize do
  Rails.logger.info 'AutoAssignmentFixPatch: Loading...'

  AutoAssignmentHandler.module_eval do
    private

    def run_auto_assignment
      return unless conversation_status_changed_to_open?
      return unless should_run_auto_assignment?

      if inbox.auto_assignment_v2_enabled?
        AutoAssignment::AssignmentJob.set(wait: 3.seconds).perform_later(inbox_id: inbox.id)
      else
        allowed_agent_ids = team_id.present? ? team_member_ids_with_capacity : inbox.member_ids_with_assignment_capacity
        AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: allowed_agent_ids).perform
      end
    end
  end

  Rails.logger.info 'AutoAssignmentFixPatch: Added 3s delay to AssignmentJob (fixes transaction race condition)'
end
