require "rails_helper"

RSpec.describe EmbedDomain do
  describe "default_item_type" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }

    def build_domain(default_item_type:)
      build(:embed_domain, organization: organization, project: project, default_item_type: default_item_type)
    end

    it "accepts a type configured for the organization" do
      expect(build_domain(default_item_type: "idea")).to be_valid
    end

    it "normalizes case and whitespace" do
      domain = build_domain(default_item_type: "  Idea ")

      expect(domain).to be_valid
      expect(domain.default_item_type).to eq("idea")
    end

    it "normalizes blank to nil, meaning no default" do
      domain = build_domain(default_item_type: "  ")

      expect(domain).to be_valid
      expect(domain.default_item_type).to be_nil
    end

    it "rejects a type the organization does not have" do
      expect(build_domain(default_item_type: "banana")).not_to be_valid
    end
  end
end
