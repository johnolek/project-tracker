class SearchController < ApplicationController
  before_action :require_login

  MAX_RESULTS = 50

  def show
    @query = params[:q].to_s.strip
    @projects = @query.present? ? matching_projects : Project.none
    @items = @query.present? ? matching_items : Item.none
  end

  private

  # @return [ActiveRecord::Relation<Project>] the organization's projects whose
  #   name contains the query as a literal substring
  def matching_projects
    current_organization.projects
                        .where("projects.name ILIKE ?", like_pattern)
                        .order(:name)
                        .limit(MAX_RESULTS)
  end

  # @return [ActiveRecord::Relation<Item>] items in the current organization
  #   whose title contains the query as a literal substring, newest first
  def matching_items
    Item.joins(:project)
        .where(projects: { organization_id: current_organization.id })
        .where("items.title ILIKE ?", like_pattern)
        .includes(:project, :status, :tags)
        .order(updated_at: :desc)
        .limit(MAX_RESULTS)
  end

  def like_pattern
    "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
  end
end
