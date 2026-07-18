require "rails_helper"

RSpec.describe "Settings::ItemTypes", type: :request do
  before { register_passkey(username: "owner") }

  let(:organization) { User.find_by(username: "owner").default_organization }

  describe "GET /settings/item_types" do
    it "lists the organization's item types" do
      get settings_item_types_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("bug")
      expect(response.body).to include("feature")
    end
  end

  describe "POST /settings/item_types" do
    it "creates a type and auto-assigns a color" do
      expect { post settings_item_types_path, params: { item_type: { name: "spike" } } }
        .to change { organization.item_types.count }.by(1)

      expect(organization.item_types.find_by(name: "spike").color).to match(/\A#\h{6}\z/i)
      expect(response).to redirect_to(settings_item_types_path)
    end

    it "rejects a duplicate name" do
      post settings_item_types_path, params: { item_type: { name: "bug" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /settings/item_types/:id" do
    it "updates the color and cascades a rename to items using it" do
      project = organization.projects.create!(name: "P")
      item = create(:item, project: project, item_type: "idea")
      type = organization.item_types.find_by!(name: "idea")

      patch settings_item_type_path(type), params: { item_type: { name: "concept", color: "#123456" } }

      expect(response).to redirect_to(settings_item_types_path)
      expect(type.reload).to have_attributes(name: "concept", color: "#123456")
      expect(item.reload.item_type).to eq("concept")
    end
  end

  describe "DELETE /settings/item_types/:id" do
    it "deletes an unused type" do
      type = organization.item_types.create!(name: "temp", color: "#123456", position: 99)
      delete settings_item_type_path(type)
      expect(organization.item_types.exists?(id: type.id)).to be(false)
    end

    it "refuses to delete a type still in use" do
      project = organization.projects.create!(name: "P")
      create(:item, project: project, item_type: "bug")
      type = organization.item_types.find_by!(name: "bug")

      delete settings_item_type_path(type)

      expect(organization.item_types.exists?(id: type.id)).to be(true)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /settings/item_types/:id/move" do
    it "swaps position with the neighbor in the given direction" do
      first, second = organization.item_types.ordered.first(2)

      patch move_settings_item_type_path(first, direction: "down")

      expect(first.reload.position).to be > second.reload.position
    end
  end
end
