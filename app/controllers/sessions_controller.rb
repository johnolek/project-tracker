class SessionsController < ApplicationController
  def new
  end

  # Issues WebAuthn assertion options for the named user and stashes the challenge for #create.
  def options
    user = User.find_by(username: params[:username].to_s.strip)

    if user.nil? || user.credentials.empty?
      return render json: { error: "No passkey found for that username." }, status: :unprocessable_entity
    end

    get_options = WebAuthn::Credential.options_for_get(
      allow: user.credentials.pluck(:external_id),
      user_verification: "preferred"
    )

    session[:authentication] = { challenge: get_options.challenge, user_id: user.id }

    render json: get_options
  end

  # Verifies the passkey assertion and signs the user in.
  def create
    authentication = session[:authentication]

    if authentication.blank?
      return render json: { error: "Your sign-in session expired. Please try again." }, status: :unprocessable_entity
    end

    user = User.find(authentication["user_id"])
    webauthn_credential = WebAuthn::Credential.from_get(credential_param)
    stored_credential = user.credentials.find_by!(external_id: webauthn_credential.id)

    webauthn_credential.verify(
      authentication["challenge"],
      public_key: stored_credential.public_key,
      sign_count: stored_credential.sign_count
    )

    stored_credential.update!(sign_count: webauthn_credential.sign_count)

    sign_in(user)
    render json: { redirect_url: root_path }
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound
    render json: { error: "We couldn't verify that passkey." }, status: :unprocessable_entity
  end

  def destroy
    sign_out
    redirect_to login_path, notice: "You have been signed out."
  end

  private

  def credential_param
    params.require(:credential).permit!.to_h
  end
end
