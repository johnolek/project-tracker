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

      # Finds an item in the organization by numeric id or human key. Keys
      # always contain a dash and ids never do, so the two are unambiguous;
      # key lookups are case-insensitive ("proj-12" works).
      #
      # @param param [String] "42" or "PROJ-12"
      # @return [Item]
      # @raise [ActiveRecord::RecordNotFound]
      def find_organization_item(param)
        scope = Item.joins(:project).where(projects: { organization_id: current_organization.id })
        if (key = param.to_s.match(/\A([A-Za-z][A-Za-z0-9]{0,9})-(\d+)\z/))
          scope.find_by!(projects: { slug: key[1].upcase }, number: key[2].to_i)
        else
          scope.find(param)
        end
      end

      # Finds a project in the organization by numeric id or slug ("PROJ").
      # Slugs start with a letter, so an all-digits param is unambiguously an id.
      #
      # @param param [String] "7" or "PROJ"
      # @return [Project]
      # @raise [ActiveRecord::RecordNotFound]
      def find_organization_project(param)
        scope = current_organization.projects
        if param.to_s.match?(/\A\d+\z/)
          scope.find(param)
        else
          scope.find_by!(slug: param.to_s.upcase)
        end
      end
    end
  end
end
