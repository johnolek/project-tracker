require "rails_helper"

RSpec.describe "Email verification", type: :request do
  def emailed_verification_token
    ActionMailer::Base.deliveries.last.body.encoded[%r{/verify-email/([^"\s<]+)}, 1]
  end

  describe "at signup" do
    it "creates an unverified user and emails a verification link" do
      expect { register_passkey(username: "newbie", email: "newbie@example.com") }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      user = User.find_by(username: "newbie")
      expect(user.email_verified?).to be(false)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "newbie@example.com" ])
    end
  end

  describe "confirming the link" do
    it "verifies the email and signs the user in from the link" do
      register_passkey(username: "newbie", email: "newbie@example.com")
      delete logout_path
      token = emailed_verification_token

      get email_verification_path(token: token)
      expect(response).to redirect_to(root_path)

      expect(User.find_by(username: "newbie").email_verified?).to be(true)

      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid or expired token" do
      get email_verification_path(token: "garbage")
      expect(response).to redirect_to(login_path)
    end
  end

  describe "resending" do
    it "re-sends the link to a signed-in, unverified user" do
      register_passkey(username: "newbie", email: "newbie@example.com")
      ActionMailer::Base.deliveries.clear

      expect { post email_verification_request_path }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response).to redirect_to(edit_settings_account_path)
    end
  end
end
