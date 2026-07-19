# Proving control of an email address. A verification link is sent at signup and
# whenever the email changes; the address isn't usable for email sign-in or
# recovery until it's confirmed here.
class EmailVerificationsController < ApplicationController
  before_action :require_login, only: :create

  # POST /verify-email — (re)send the verification link to the current user.
  def create
    if current_user.email.present? && !current_user.email_verified?
      EmailVerificationMailer.verify_email(current_user).deliver_now
      redirect_to edit_settings_account_path, notice: "Verification email sent to #{current_user.email}."
    else
      redirect_to edit_settings_account_path
    end
  end

  # GET /verify-email/:token — confirm the address and sign in. Acting on the
  # link directly is safe: marking an email verified is idempotent and is exactly
  # what the recipient wants, so no interstitial confirm is needed.
  def show
    user = User.find_by_token_for(:email_verification, params[:token])

    if user
      user.update_column(:email_verified_at, Time.current)
      sign_in(user)
      redirect_to root_path, notice: "Email verified — you're all set."
    else
      redirect_to login_path, alert: "That verification link is invalid or has expired."
    end
  end
end
