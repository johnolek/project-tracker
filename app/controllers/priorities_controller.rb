class PrioritiesController < ApplicationController
  before_action :require_login

  def index
    @project = current_organization.projects.find(params[:id])
    @items = @project.items.not_done.includes(:status).order(strength: :desc, id: :asc)
    @comparison_counts = Comparison.counts_by_item(project: @project)
  end
end
