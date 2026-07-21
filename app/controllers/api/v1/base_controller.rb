module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      # Populates ActiveStorage::Current.url_options from the request so the
      # item serializer can render absolute blob URLs for note attachments.
      include ActiveStorage::SetCurrent

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
        if (key = param.to_s.match(/\A([A-Za-z][A-Za-z0-9]{0,9})-(\d+)\z/))
          project = resolve_project_by_slug(key[1]) || raise(ActiveRecord::RecordNotFound)
          project.items.published.find_by!(number: key[2].to_i)
        else
          Item.published.joins(:project).where(projects: { organization_id: current_organization.id }).find(param)
        end
      end

      # Finds a project in the organization by numeric id or slug ("PROJ"),
      # including retired slugs. Slugs start with a letter, so an all-digits
      # param is unambiguously an id.
      #
      # @param param [String] "7" or "PROJ"
      # @return [Project]
      # @raise [ActiveRecord::RecordNotFound]
      def find_organization_project(param)
        return current_organization.projects.find(param) if param.to_s.match?(/\A\d+\z/)

        resolve_project_by_slug(param) || raise(ActiveRecord::RecordNotFound)
      end

      # Resolves a slug to a project by its current slug, then by a retired slug
      # (so old keys/URLs keep working after a slug change).
      #
      # @param slug [String]
      # @return [Project, nil]
      def resolve_project_by_slug(slug)
        up = slug.to_s.upcase
        current_organization.projects.find_by(slug: up) ||
          current_organization.project_slug_aliases.find_by(slug: up)&.project
      end

      # @return [Boolean] true when a project was addressed by a retired slug
      def stale_project_slug?(param, project)
        return false if param.to_s.match?(/\A\d+\z/)

        param.to_s.upcase != project.slug
      end

      # @return [Boolean] true when an item was addressed by a key whose slug
      #   part is a retired slug (a numeric id never redirects)
      def stale_item_key?(param, item)
        key = param.to_s.match(/\A([A-Za-z][A-Za-z0-9]{0,9})-(\d+)\z/)
        return false unless key

        key[1].upcase != item.project.slug
      end
    end
  end
end
