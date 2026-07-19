class EmailVerificationMailer < ApplicationMailer
  # Sends a link (valid for 24 hours) that proves the user controls the address.
  def verify_email(user)
    @user = user
    @url = email_verification_url(token: user.generate_token_for(:email_verification))

    mail(to: user.email, subject: "Verify your Project Tracker email")
  end
end
