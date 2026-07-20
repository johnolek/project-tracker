require "rails_helper"

RSpec.describe "Failed email surfacing", type: :request do
  def create_failed_delivery(mailer: "EmailSignInMailer", action: "sign_in_link", message: "SMTP2GO refused")
    job = SolidQueue::Job.create!(
      queue_name: "default",
      class_name: FailedEmail::MAIL_JOB_CLASS,
      arguments: {
        "job_class" => FailedEmail::MAIL_JOB_CLASS,
        "arguments" => [ mailer, action, "deliver_now" ]
      }
    )
    SolidQueue::FailedExecution.create!(
      job: job,
      error: { "exception_class" => "Smtp2goDelivery::Error", "message" => message, "backtrace" => [] }
    )
  end

  before { register_passkey(username: "owner") }

  it "banners signed-in pages while a mail job sits failed, and clears after dismiss" do
    failed = create_failed_delivery(message: "sender not verified")

    get projects_path
    expect(response.body).to include("1 email failed to send")

    get edit_settings_admin_path
    expect(response.body).to include("EmailSignInMailer#sign_in_link")
    expect(response.body).to include("sender not verified")

    delete failed_email_settings_admin_path(failed_execution_id: failed.id)
    expect(FailedEmail.count).to eq(0)

    get projects_path
    expect(response.body).not_to include("failed to send")
  end

  it "retry re-enqueues the delivery and removes the failure record" do
    failed = create_failed_delivery

    expect do
      post retry_failed_email_settings_admin_path(failed_execution_id: failed.id)
    end.to change { SolidQueue::FailedExecution.count }.by(-1)

    expect(response).to redirect_to(edit_settings_admin_path)
    expect(SolidQueue::Job.exists?(failed.job_id)).to be(true)
  end

  it "ignores failed jobs that are not mail deliveries" do
    job = SolidQueue::Job.create!(
      queue_name: "default",
      class_name: "SomeOtherJob",
      arguments: { "job_class" => "SomeOtherJob", "arguments" => [] }
    )
    SolidQueue::FailedExecution.create!(job: job, error: { "message" => "boom" })

    expect(FailedEmail.count).to eq(0)
  end
end
