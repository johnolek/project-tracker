class RegistrationsController < ApplicationController
  def new
  end

  # Issues WebAuthn credential-creation options and stashes the challenge for #create.
  def options
    username = params[:username].to_s.strip

    if username.blank?
      return render json: { error: "Please choose a username." }, status: :unprocessable_entity
    end

    if User.exists?(username: username)
      return render json: { error: "That username is taken." }, status: :unprocessable_entity
    end

    webauthn_id = WebAuthn.generate_user_id
    create_options = WebAuthn::Credential.options_for_create(
      user: { id: webauthn_id, name: username, display_name: username },
      authenticator_selection: { user_verification: "preferred", resident_key: "preferred" }
    )

    session[:registration] = {
      challenge: create_options.challenge,
      username: username,
      webauthn_id: webauthn_id
    }

    render json: create_options
  end

  # Verifies the new passkey, creates the user (and their personal org), and signs in.
  def create
    registration = session[:registration]

    if registration.blank?
      return render json: { error: "Your registration session expired. Please try again." }, status: :unprocessable_entity
    end

    webauthn_credential = WebAuthn::Credential.from_create(credential_param)
    webauthn_credential.verify(registration["challenge"])

    user = User.new(username: registration["username"], webauthn_id: registration["webauthn_id"])
    user.credentials.build(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      nickname: params[:nickname].presence
    )
    user.save!

    sign_in(user)
    render json: { redirect_url: root_path }
  rescue WebAuthn::Error => e
    render json: { error: "Passkey could not be verified: #{e.message}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def credential_param
    params.require(:credential).permit!.to_h
  end
end
