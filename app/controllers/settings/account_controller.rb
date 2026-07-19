module Settings
  class AccountController < ApplicationController
    before_action :require_login

    def edit
      @user = current_user
    end

    def update
      @user = current_user

      if @user.update(account_params)
        if @user.saved_change_to_email? && @user.email.present?
          EmailVerificationMailer.verify_email(@user).deliver_now
          redirect_to edit_settings_account_path, notice: "Saved. Check #{@user.email} to verify the new address."
        else
          redirect_to edit_settings_account_path, notice: "Account updated."
        end
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
