require "rails_helper"

RSpec.describe "Item broadcasting", type: :model do
  let(:project) { create(:project) }
  let(:board_target) { ActionView::RecordIdentifier.dom_id(project, :board) }

  before do
    @broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) do |_stream, message|
      @broadcasts << message.to_s
    end
  end

  it "broadcasts a board update when an item is created" do
    project.items.create!(title: "Live item")

    expect(@broadcasts).not_to be_empty
    expect(@broadcasts.last).to include(board_target)
    expect(@broadcasts.last).to include("Live item")
  end

  it "broadcasts a fresh board when an item's status changes" do
    item = project.items.create!(title: "Movable")
    completed = project.organization.statuses.find_by(category: "done")
    @broadcasts.clear

    item.update!(status: completed)

    expect(@broadcasts).not_to be_empty
    expect(@broadcasts.last).to include("Movable")
  end

  it "broadcasts a board without the item when it is destroyed" do
    item = project.items.create!(title: "Temporary")
    @broadcasts.clear

    item.destroy!

    expect(@broadcasts).not_to be_empty
    expect(@broadcasts.last).not_to include("Temporary")
  end
end
