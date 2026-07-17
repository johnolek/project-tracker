# Streams JSON board changes for one project: item upserts/removes from
# Item callbacks and bulk strength refreshes from Item.recompute_strengths.
# Scoped like the controllers: only projects in the subscriber's default
# organization.
class BoardChannel < ApplicationCable::Channel
  def subscribed
    project = current_user.default_organization&.projects&.find_by(id: params[:project_id])
    project ? stream_for(project) : reject
  end
end
