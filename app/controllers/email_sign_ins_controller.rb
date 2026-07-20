# Passwordless email sign-in: request a magic link, then confirm it. Works on
# any domain, so it doubles as the recovery path when a passkey can't be used
# (domain/RP-ID change or a lost device) — sign in here, then enroll a passkey.
class EmailSignInsController < ApplicationController
  # Sends outbound email on request; throttled per-IP (PROJ-76).
  rate_limit to: 5, within: 1.minute, only: :create,
             with: -> { redirect_to login_path, alert: "Too many attempts — try again in a minute." }

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

  # GET /sign-in/email/:token — verify the token and sign in. Acting on the link
  # directly matches how email magic links work elsewhere; the token expires and
  # isn't single-use, so link prefetchers don't break it for the real click.
  def show
    user = User.find_by_token_for(:email_login, params[:token])

    if user
      sign_in(user)
      redirect_to root_path, notice: "Signed in."
    else
      redirect_to login_path, alert: "That sign-in link is invalid or has expired."
    end
  end
end
