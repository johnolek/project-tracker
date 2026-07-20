# Failed mail-delivery jobs surfaced to the (single) user (PROJ-84): with
# deliver_later, a failed send is otherwise just a Solid Queue failed-execution
# row nobody sees. Wraps SolidQueue so callers get plain values and the app
# still boots/renders when the queue tables are absent (fresh envs, adapters
# other than solid_queue).
class FailedEmail
  Entry = Struct.new(:failed_execution_id, :mailer, :action, :message, :failed_at)

  MAIL_JOB_CLASS = "ActionMailer::MailDeliveryJob"

  # @return [Boolean]
  def self.available?
    defined?(SolidQueue::FailedExecution) && SolidQueue::FailedExecution.table_exists?
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # @return [Integer]
  def self.count
    available? ? scope.count : 0
  end

  # @return [Array<Entry>] newest first
  def self.all
    return [] unless available?

    scope.includes(:job).map do |failed|
      arguments = failed.job.arguments.to_h["arguments"] || []
      Entry.new(failed.id, arguments[0] || "Unknown mailer", arguments[1] || "?", failed.message.to_s, failed.created_at)
    end
  end

  # @param failed_execution_id [Integer]
  # @return [void] re-enqueues the delivery
  def self.retry(failed_execution_id)
    SolidQueue::FailedExecution.find(failed_execution_id).retry
  end

  # @param failed_execution_id [Integer]
  # @return [void] discards the failure (and its job) without retrying
  def self.discard(failed_execution_id)
    SolidQueue::FailedExecution.find(failed_execution_id).job.destroy!
  end

  def self.scope
    SolidQueue::FailedExecution.joins(:job)
                               .where(solid_queue_jobs: { class_name: MAIL_JOB_CLASS })
                               .order(created_at: :desc)
  end
  private_class_method :scope
end
