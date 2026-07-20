require "rails_helper"

RSpec.describe "Signup lockdown and rate limits", type: :request do
  describe "when signups are closed by the admin setting" do
    before { AppSetting.instance.update!(allow_signups: false) }

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

  describe "the admin setting" do
    it "reopens signups when set to open" do
      AppSetting.instance.update!(allow_signups: false)
      AppSetting.instance.update!(allow_signups: true)

      expect do
        post signup_path, params: { username: "invited", email: "invited@example.com" }
      end.to change(User, :count).by(1)
    end

    it "is editable from the admin settings page" do
      register_passkey(username: "owner")

      patch settings_admin_path, params: { app_setting: { allow_signups: "false" } }
      expect(AppSetting.instance.reload.allow_signups).to be(false)

      patch settings_admin_path, params: { app_setting: { allow_signups: "auto" } }
      expect(AppSetting.instance.reload.allow_signups).to be_nil
    end

    it "requires login to edit" do
      patch settings_admin_path, params: { app_setting: { allow_signups: "true" } }

      expect(response).to redirect_to(login_path)
      expect(AppSetting.instance.allow_signups).to be_nil
    end

    it "is admin-only: the first account is admin, later accounts are not" do
      create(:user)
      register_passkey(username: "latecomer")

      expect(User.find_by(username: "latecomer").admin?).to be(false)

      get edit_settings_admin_path
      expect(response).to redirect_to(root_path)

      patch settings_admin_path, params: { app_setting: { allow_signups: "true" } }
      expect(AppSetting.instance.allow_signups).to be_nil
    end

    it "grants admin to the very first account automatically" do
      post signup_path, params: { username: "founder", email: "founder@example.com" }

      expect(User.find_by(username: "founder").admin?).to be(true)
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
