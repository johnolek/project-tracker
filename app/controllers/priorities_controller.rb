class PrioritiesController < ApplicationController
  before_action :require_login

  def index
    @items = Item.joins(:project).where(projects: { organization_id: current_organization.id })
                 .not_done
                 .includes(:project, :status)
                 .order(strength: :desc, id: :asc)
    @comparison_counts = Comparison.counts_by_item(organization: current_organization)
  end
end
