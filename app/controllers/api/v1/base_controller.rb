module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_key!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end

      rescue_from ActionController::ParameterMissing do |exception|
        render json: { error: exception.message }, status: :unprocessable_entity
      end

      rescue_from ActiveRecord::RecordInvalid do |exception|
        render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      attr_reader :current_api_key

      def authenticate_api_key!
        authenticate_with_http_token do |token, _options|
          @current_api_key = ApiKey.authenticate(token)
        end

        if current_api_key
          current_api_key.touch_last_used
        else
          render json: { error: "Invalid or missing API token" }, status: :unauthorized
        end
      end

      # @return [User] the owner of the authenticated key
      def current_user
        current_api_key.user
      end

      # @return [Organization] the organization every API query must be scoped to
      def current_organization
        current_api_key.organization
      end
    end
  end
end
