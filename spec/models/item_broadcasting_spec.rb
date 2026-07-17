require "rails_helper"

RSpec.describe "Item broadcasting", type: :model do
  let(:project) { create(:project) }
  let(:stream) { BoardChannel.broadcasting_for(project) }

  before do
    @broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) do |stream_name, message|
      @broadcasts << [ stream_name, message ]
    end
  end

  it "broadcasts an upsert with the item payload when an item is created" do
    item = project.items.create!(title: "Live item")

    stream_name, message = @broadcasts.last
    expect(stream_name).to eq(stream)
    expect(message[:action]).to eq("upsert")
    expect(message[:item][:title]).to eq("Live item")
    expect(message[:item][:status_id]).to eq(item.status_id)
  end

  it "broadcasts an upsert with the new status when an item moves" do
    item = project.items.create!(title: "Movable")
    completed = project.organization.statuses.find_by(category: "done")
    @broadcasts.clear

    item.update!(status: completed)

    message = @broadcasts.last.last
    expect(message[:action]).to eq("upsert")
    expect(message[:item][:status_id]).to eq(completed.id)
  end

  it "broadcasts a remove carrying only the id when an item is destroyed" do
    item = project.items.create!(title: "Temporary")
    @broadcasts.clear

    item.destroy!

    expect(@broadcasts.last.last).to eq({ action: "remove", id: item.id })
  end
end
