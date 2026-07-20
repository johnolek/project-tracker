class RegistrationsController < ApplicationController
  before_action :ensure_signups_open

  # Signup sends email to a visitor-typed address and options/create hit the
  # DB per request, so all of it is throttled (PROJ-76). Per-IP, in-memory —
  # plenty for a single-user app behind one Puma.
  rate_limit to: 5, within: 1.minute, with: -> { signup_rate_limited }

  def new
    @user = User.new
  end

  # Email-only signup: no passkey. Creates the account and emails a link to
  # verify + sign in. A passkey is optional and can be added later. A webauthn_id
  # is reserved now so one can be enrolled without a migration.
  def create
    @user = User.new(
      username: params[:username].to_s.strip,
      email: params[:email].to_s.strip.downcase,
      webauthn_id: WebAuthn.generate_user_id
    )

    if @user.save
      EmailVerificationMailer.verify_email(@user).deliver_later
      redirect_to login_path, notice: "Account created. Check #{@user.email} for a link to sign in and finish setting up."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Issues WebAuthn credential-creation options and stashes the challenge for #create_passkey.
  def options
    username = params[:username].to_s.strip
    email = params[:email].to_s.strip.downcase

    if username.blank?
      return render json: { error: "Please choose a username." }, status: :unprocessable_entity
    end
    if User.exists?(username: username)
      return render json: { error: "That username is taken." }, status: :unprocessable_entity
    end
    if email.blank?
      return render json: { error: "Please enter an email for sign-in and recovery." }, status: :unprocessable_entity
    end
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return render json: { error: "Please enter a valid email address." }, status: :unprocessable_entity
    end
    if User.exists?([ "lower(email) = ?", email ])
      return render json: { error: "That email is already registered." }, status: :unprocessable_entity
    end

    webauthn_id = WebAuthn.generate_user_id
    create_options = WebAuthn::Credential.options_for_create(
      user: { id: webauthn_id, name: username, display_name: username },
      authenticator_selection: { user_verification: "preferred", resident_key: "required" }
    )

    session[:registration] = {
      challenge: create_options.challenge,
      username: username,
      webauthn_id: webauthn_id,
      email: email
    }

    render json: create_options
  end

  # Verifies the new passkey, creates the user (and their personal org), and signs
  # in. This is the optional passkey path; #create handles email-only signup.
  def create_passkey
    registration = session[:registration]

    if registration.blank?
      return render json: { error: "Your registration session expired. Please try again." }, status: :unprocessable_entity
    end

    webauthn_credential = WebAuthn::Credential.from_create(credential_param)
    webauthn_credential.verify(registration["challenge"])

    user = User.new(username: registration["username"], webauthn_id: registration["webauthn_id"], email: registration["email"])
    user.credentials.build(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      nickname: params[:nickname].presence
    )
    user.save!
    EmailVerificationMailer.verify_email(user).deliver_later

    sign_in(user)
    render json: { redirect_url: root_path }
  rescue WebAuthn::Error => e
    render json: { error: "Passkey could not be verified: #{e.message}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def ensure_signups_open
    return if AppSetting.signups_open?

    respond_to do |format|
      format.html { redirect_to login_path, alert: "Sign-ups are closed." }
      format.json { render json: { error: "Sign-ups are closed." }, status: :forbidden }
    end
  end

  # The JSON ceremony endpoints and the HTML form need different shapes.
  def signup_rate_limited
    respond_to do |format|
      format.html { redirect_to login_path, alert: "Too many attempts — try again in a minute." }
      format.json { render json: { error: "Too many attempts — try again in a minute." }, status: :too_many_requests }
    end
  end

  def credential_param
    params.require(:credential).permit!.to_h
  end
end
