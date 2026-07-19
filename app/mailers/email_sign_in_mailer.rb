class EmailSignInMailer < ApplicationMailer
  # Sends a one-tap sign-in link (valid for 20 minutes) to the user's email.
  def sign_in_link(user)
    @user = user
    @url = email_sign_in_url(token: user.generate_token_for(:email_login))

    mail(to: user.email, subject: "Your Project Tracker sign-in link")
  end
end
