require "rails_helper"

RSpec.describe "Email sign-in", type: :request do
  let!(:user) { create(:user, email: "owner@example.com") }

  # Pull the magic-link token out of the most recently delivered email.
  def emailed_token
    ActionMailer::Base.deliveries.last.body.encoded[%r{/sign-in/email/([^"\s<]+)}, 1]
  end

  describe "requesting a link" do
    it "emails a sign-in link to a registered address" do
      expect { post email_sign_in_request_path, params: { email: "owner@example.com" } }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(login_path)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "owner@example.com" ])
    end

    it "does not reveal whether an address is unknown" do
      expect { post email_sign_in_request_path, params: { email: "nobody@example.com" } }
        .not_to change { ActionMailer::Base.deliveries.count }

      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to be_present
    end

    it "does not send a link to an unverified email" do
      create(:user, email: "pending@example.com", email_verified: false)

      expect { post email_sign_in_request_path, params: { email: "pending@example.com" } }
        .not_to change { ActionMailer::Base.deliveries.count }

      expect(response).to redirect_to(login_path)
    end
  end

  describe "using the link" do
    it "signs the user in after confirming a valid token" do
      post email_sign_in_request_path, params: { email: "owner@example.com" }
      token = emailed_token

      get email_sign_in_path(token: token)
      expect(response).to have_http_status(:ok)

      post email_sign_in_path(token: token)
      expect(response).to redirect_to(root_path)

      # Session is authenticated: a login-required page renders.
      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid or expired token" do
      get email_sign_in_path(token: "garbage")
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to be_present

      post email_sign_in_path(token: "garbage")
      expect(response).to redirect_to(login_path)
    end
  end
end
