class PrioritiesController < ApplicationController
  before_action :require_login

  def index
    @project = find_project!(params[:id])
    @items = @project.items.published.not_done.includes(:status).order(strength: :desc, id: :asc)
    @comparison_counts = Comparison.counts_by_item(project: @project)
  end
end
