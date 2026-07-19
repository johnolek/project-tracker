# Passwordless email sign-in: request a magic link, then confirm it. Works on
# any domain, so it doubles as the recovery path when a passkey can't be used
# (domain/RP-ID change or a lost device) — sign in here, then enroll a passkey.
class EmailSignInsController < ApplicationController
  # POST /sign-in/email — email a sign-in link for the given address.
  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by("lower(email) = ?", email) if email.present?

    # Only verified addresses can sign in by email — an unverified email hasn't
    # been proven, so it isn't a usable way in.
    EmailSignInMailer.sign_in_link(user).deliver_now if user&.email_verified?

    # Neutral response either way so the form never reveals who has an account.
    redirect_to login_path, notice: "If that email has an account, a sign-in link is on its way."
  end

  # GET /sign-in/email/:token — confirm before signing in, so an email-link
  # prefetcher can't silently establish a session from the token.
  def show
    @user = User.find_by_token_for(:email_login, params[:token])

    redirect_to login_path, alert: "That sign-in link is invalid or has expired." if @user.nil?
  end

  # POST /sign-in/email/:token — verify the token and sign in.
  def update
    user = User.find_by_token_for(:email_login, params[:token])

    if user
      sign_in(user)
      redirect_to root_path, notice: "Signed in."
    else
      redirect_to login_path, alert: "That sign-in link is invalid or has expired."
    end
  end
end
