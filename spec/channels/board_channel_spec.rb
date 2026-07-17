require "rails_helper"

RSpec.describe BoardChannel, type: :channel do
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: user.default_organization) }

  it "streams for a project in the subscriber's default organization" do
    stub_connection current_user: user

    subscribe project_id: project.id

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(project)
  end

  it "rejects a project from another organization" do
    stub_connection current_user: user

    subscribe project_id: create(:project).id

    expect(subscription).to be_rejected
  end

  it "rejects an unknown project" do
    stub_connection current_user: user

    subscribe project_id: -1

    expect(subscription).to be_rejected
  end
end
