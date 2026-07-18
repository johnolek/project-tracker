require "rails_helper"

RSpec.describe "Item links", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Board") }
    let(:item) { create(:item, project: project, title: "Ship it") }
    let(:other) { create(:item, project: project, title: "Groundwork") }

    it "adds a blocks link from the item page form" do
      post project_item_links_path(project, item), params: { link: { kind: "blocks", target_id: other.id } }

      expect(response).to redirect_to(project_item_path(project, item))
      expect(ItemLink.sole).to have_attributes(source: item, target: other, kind: "blocks")
    end

    it "stores blocked_by as the reversed blocks edge" do
      post project_item_links_path(project, item), params: { link: { kind: "blocked_by", target_id: other.id } }

      expect(ItemLink.sole).to have_attributes(source: other, target: item, kind: "blocks")
    end

    it "redirects back with the validation message when the link is invalid" do
      create(:item_link, source: item, target: other, kind: "blocks")

      post project_item_links_path(project, item), params: { link: { kind: "blocks", target_id: other.id } }

      expect(response).to redirect_to(project_item_path(project, item))
      expect(flash[:alert]).to include("already linked")
      expect(ItemLink.count).to eq(1)
    end

    it "404s a target from another organization" do
      foreign = create(:item)

      post project_item_links_path(project, item), params: { link: { kind: "blocks", target_id: foreign.id } }

      expect(response).to have_http_status(:not_found)
      expect(ItemLink.count).to eq(0)
    end

    it "removes a link from either endpoint's page" do
      link = create(:item_link, source: other, target: item)

      delete project_item_link_path(project, item, link)

      expect(response).to redirect_to(project_item_path(project, item))
      expect(ItemLink.exists?(link.id)).to be(false)
    end

    it "renders the relationship buckets on the item page" do
      create(:item_link, source: item, target: other, kind: "blocks")
      related = create(:item, project: project, title: "Cousin work")
      create(:item_link, source: related, target: item, kind: "relates_to")

      get project_item_path(project, item)

      links_section = Nokogiri::HTML(response.body).at_css(".item-links")
      expect(links_section.css(".item-links-label").map(&:text)).to eq([ "Blocks", "Related to" ])
      expect(links_section.text).to include(other.key, "Groundwork", related.key, "Cousin work")
      expect(links_section.css("form.item-row-remove").size).to eq(2)
    end
  end

  context "when signed out" do
    it "redirects to the login page" do
      link = create(:item_link)
      project = link.source.project

      post project_item_links_path(project, link.source), params: { link: { kind: "blocks", target_id: link.target_id } }

      expect(response).to redirect_to(login_path)
    end
  end
end
