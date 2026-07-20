require "rails_helper"

RSpec.describe "Signup lockdown and rate limits", type: :request do
  describe "when signups are closed" do
    around do |example|
      original = Rails.configuration.x.allow_signups
      Rails.configuration.x.allow_signups = false
      example.run
    ensure
      Rails.configuration.x.allow_signups = original
    end

    it "redirects the signup form away" do
      get signup_path

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq("Sign-ups are closed.")
    end

    it "refuses account creation" do
      expect do
        post signup_path, params: { username: "intruder", email: "intruder@example.com" }
      end.not_to change(User, :count)

      expect(response).to redirect_to(login_path)
    end

    it "refuses the passkey ceremony endpoints as JSON" do
      post signup_options_path, params: { username: "intruder", email: "i@example.com" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("Sign-ups are closed.")
    end

    it "hides the register links" do
      get login_path, headers: { "HTTP_ACCEPT" => "text/html" }
      follow_redirect! while response.redirect?

      expect(response.body).not_to include(signup_path)
    end
  end

  describe "rate limiting" do
    it "throttles email sign-in requests per IP" do
      5.times do
        post email_sign_in_request_path, params: { email: "someone@example.com" }
        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to be_nil
      end

      post email_sign_in_request_path, params: { email: "someone@example.com" }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("Too many attempts")
    end

    it "throttles signup attempts per IP" do
      5.times { post signup_path, params: { username: "", email: "" } }

      expect do
        post signup_path, params: { username: "fresh", email: "fresh@example.com" }
      end.not_to change(User, :count)
      expect(flash[:alert]).to include("Too many attempts")
    end
  end
end
