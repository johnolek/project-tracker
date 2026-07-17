module Settings
  class ApiKeysController < ApplicationController
    before_action :require_login

    def index
      @api_keys = api_keys_scope
    end

    def create
      @api_key = current_user.api_keys.new(api_key_params.merge(organization: current_organization))

      if @api_key.save
        flash[:api_key_token] = @api_key.token
        redirect_to settings_api_keys_path, notice: "API key created."
      else
        @api_keys = api_keys_scope
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      api_key = current_user.api_keys.find(params[:id])
      api_key.destroy
      redirect_to settings_api_keys_path, notice: "API key revoked."
    end

    private

    def api_keys_scope
      current_user.api_keys.where(organization: current_organization).order(created_at: :desc)
    end

    def api_key_params
      params.require(:api_key).permit(:name)
    end
  end
end
