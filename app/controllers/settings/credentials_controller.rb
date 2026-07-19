module Settings
  class CredentialsController < ApplicationController
    before_action :require_login

    def index
      @credentials = current_user.credentials.order(:created_at)
    end

    # Issues WebAuthn creation options for the CURRENT user so they can enroll an
    # additional passkey, excluding devices already registered, and stashes the
    # challenge for #create. Unlike signup, no user is created.
    def options
      create_options = WebAuthn::Credential.options_for_create(
        user: { id: current_user.webauthn_id, name: current_user.username, display_name: current_user.username },
        exclude: current_user.credentials.pluck(:external_id),
        authenticator_selection: { user_verification: "preferred", resident_key: "required" }
      )

      session[:credential_registration] = { challenge: create_options.challenge }
      render json: create_options
    end

    def create
      registration = session[:credential_registration]

      if registration.blank?
        return render json: { error: "Your session expired. Please try again." }, status: :unprocessable_entity
      end

      webauthn_credential = WebAuthn::Credential.from_create(credential_param)
      webauthn_credential.verify(registration["challenge"])

      current_user.credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        nickname: params[:nickname].presence
      )

      session.delete(:credential_registration)
      render json: { redirect_url: settings_credentials_path }
    rescue WebAuthn::Error => e
      render json: { error: "Passkey could not be verified: #{e.message}" }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def destroy
      credential = current_user.credentials.find(params[:id])

      if current_user.credentials.count <= 1
        redirect_to settings_credentials_path, alert: "You can't remove your only passkey — add another first."
      else
        credential.destroy
        redirect_to settings_credentials_path, notice: "Passkey removed."
      end
    end

    private

    def credential_param
      params.require(:credential).permit!.to_h
    end
  end
end
