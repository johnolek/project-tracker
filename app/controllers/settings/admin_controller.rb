module Settings
  # Instance-wide switches (the AppSetting singleton). Single-user app: any
  # signed-in account is the admin.
  class AdminController < ApplicationController
    before_action :require_login

    def edit
      @setting = AppSetting.instance
      @failed_emails = FailedEmail.all
    end

    def update
      @setting = AppSetting.instance
      @setting.update!(allow_signups: parse_tristate(params.dig(:app_setting, :allow_signups)))
      redirect_to edit_settings_admin_path, notice: "Settings saved."
    end

    def retry_email
      FailedEmail.retry(params[:failed_execution_id])
      redirect_to edit_settings_admin_path, notice: "Delivery re-enqueued."
    end

    def discard_email
      FailedEmail.discard(params[:failed_execution_id])
      redirect_to edit_settings_admin_path, notice: "Failure dismissed."
    end

    private

    # The form's select posts "auto" | "true" | "false"; auto stores nil.
    #
    # @param value [String, nil]
    # @return [Boolean, nil]
    def parse_tristate(value)
      return nil if value.blank? || value == "auto"

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
