module Settings
  class AccountController < ApplicationController
    before_action :require_login

    def edit
      @user = current_user
    end

    def update
      @user = current_user

      if @user.update(account_params)
        redirect_to edit_settings_account_path, notice: "Account updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def account_params
      params.require(:user).permit(:email)
    end
  end
end
