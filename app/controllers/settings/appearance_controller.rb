module Settings
  # Settings → Appearance (PROJ-32): pick a built-in color scheme and the
  # light/dark mode. The ThemeSettings island applies choices live and PATCHes
  # them here as JSON; the HTML path exists as a no-JS fallback.
  class AppearanceController < ApplicationController
    before_action :require_login

    def edit
      @user = current_user
    end

    def update
      @user = current_user

      if @user.update(appearance_params)
        respond_to do |format|
          format.json { render json: { color_scheme: @user.color_scheme, theme_mode: @user.theme_mode } }
          format.html { redirect_to edit_settings_appearance_path, notice: "Appearance updated." }
        end
      else
        respond_to do |format|
          format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity }
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end

    private

    def appearance_params
      params.require(:user).permit(:color_scheme, :theme_mode, custom_colors: CustomScheme::KEYS)
    end
  end
end
