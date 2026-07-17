class SearchController < ApplicationController
  before_action :require_login

  MAX_RESULTS = 50

  def show
    @query = params[:q].to_s.strip
    @items = @query.present? ? matching_items : Item.none
  end

  private

  # @return [ActiveRecord::Relation<Item>] items in the current organization
  #   whose title contains the query as a literal substring, newest first
  def matching_items
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    Item.joins(:project)
        .where(projects: { organization_id: current_organization.id })
        .where("items.title ILIKE ?", pattern)
        .includes(:project, :status, :tags)
        .order(updated_at: :desc)
        .limit(MAX_RESULTS)
  end
end
