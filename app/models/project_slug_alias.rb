# A project's retired slug, kept in reserve after a slug change so old
# references (web + API) can be redirected to the project's current slug and no
# other project can claim the name. Organization is denormalized from the
# project so a retired slug is unique per organization at the DB level.
class ProjectSlugAlias < ApplicationRecord
  belongs_to :project
  belongs_to :organization

  before_validation :inherit_organization, on: :create

  validates :slug, presence: true,
                   uniqueness: { scope: :organization_id, case_sensitive: false },
                   format: { with: Project::SLUG_FORMAT }

  private

  def inherit_organization
    self.organization ||= project&.organization
  end
end
