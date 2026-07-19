require "rails_helper"

RSpec.describe "Settings::Account", type: :request do
  before { register_passkey(username: "owner", email: "owner@example.com") }

  let(:user) { User.find_by(username: "owner") }

  it "shows the account page with the current email" do
    get edit_settings_account_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("owner@example.com")
  end

  it "updates the email, marks it unverified, and sends a verification link" do
    expect { patch settings_account_path, params: { user: { email: "new@example.com" } } }
      .to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(response).to redirect_to(edit_settings_account_path)
    expect(user.reload.email).to eq("new@example.com")
    expect(user.email_verified?).to be(false)
  end

  it "rejects an invalid email" do
    patch settings_account_path, params: { user: { email: "not-an-email" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.email).to eq("owner@example.com")
  end

  it "requires a signed-in user" do
    delete logout_path
    get edit_settings_account_path
    expect(response).to redirect_to(login_path)
  end
end
