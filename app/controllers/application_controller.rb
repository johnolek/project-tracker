class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :current_organization, :signed_in?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def current_organization
    current_user&.default_organization
  end

  def signed_in?
    current_user.present?
  end

  def require_login
    redirect_to login_path, alert: "Please sign in to continue." unless signed_in?
  end

  # Resolves a project by slug ("PROJ") or, for legacy URLs, numeric id. Slugs
  # always start with a letter, so an all-digits param is unambiguously an id.
  #
  # @param param [String]
  # @param scope [ActiveRecord::Relation<Project>]
  # @return [Project]
  # @raise [ActiveRecord::RecordNotFound]
  def find_project!(param, scope: current_organization.projects)
    if param.to_s.match?(/\A\d+\z/)
      scope.find(param)
    else
      scope.find_by!(slug: param.to_s.upcase)
    end
  end

  # Resolves an item within +scope+ by key ("PROJ-3") or, for legacy URLs,
  # numeric id. Keys contain a dash; ids never do.
  #
  # @param param [String]
  # @param scope [ActiveRecord::Relation<Item>]
  # @return [Item]
  # @raise [ActiveRecord::RecordNotFound]
  def find_item!(param, scope:)
    if (match = param.to_s.match(/\A[A-Za-z][A-Za-z0-9]{0,9}-(\d+)\z/))
      scope.find_by!(number: match[1].to_i)
    else
      scope.find(param)
    end
  end

  # @param user [User]
  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    @current_user = user
  end

  def sign_out
    reset_session
    @current_user = nil
  end
end
