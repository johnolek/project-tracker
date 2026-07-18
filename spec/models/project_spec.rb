require "rails_helper"

RSpec.describe Project, type: :model do
  subject { build(:project) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:items).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }

  describe "slug derivation" do
    it "takes the first four characters of the first word, upcased" do
      expect(create(:project, name: "Project Tracker").slug).to eq("PROJ")
    end

    it "keeps short one-word names whole" do
      expect(create(:project, name: "Lila").slug).to eq("LILA")
    end

    it "prefixes P when the name starts with digits" do
      expect(create(:project, name: "2048 Game").slug).to eq("P2048")
    end

    it "appends a counter when the derived slug is taken in the organization" do
      organization = create(:organization)
      create(:project, organization: organization, name: "Project Tracker")

      expect(create(:project, organization: organization, name: "Projections").slug).to eq("PROJ2")
    end

    it "allows the same slug across organizations" do
      create(:project, name: "Project One")

      expect(create(:project, name: "Project Two").slug).to eq("PROJ")
    end

    it "prefers an explicitly given slug, normalized to uppercase" do
      expect(create(:project, name: "Project Tracker", slug: " trk ").slug).to eq("TRK")
    end
  end

  describe "slug validation" do
    it "rejects slugs that do not start with a letter or exceed ten characters" do
      expect(build(:project, slug: "1ABC")).not_to be_valid
      expect(build(:project, slug: "A" * 11)).not_to be_valid
      expect(build(:project, slug: "AB-C")).not_to be_valid
      expect(build(:project, slug: "AB1")).to be_valid
    end

    it "rejects a duplicate slug within the organization" do
      organization = create(:organization)
      create(:project, organization: organization, slug: "SAME")

      expect(build(:project, organization: organization, slug: "SAME")).not_to be_valid
    end
  end

  describe "slug immutability" do
    it "allows changing the slug while the project has no items" do
      project = create(:project)

      expect(project.update(slug: "FRESH")).to be(true)
    end

    it "refuses to change the slug once items exist" do
      project = create(:project)
      project.items.create!(title: "An item")

      expect(project.update(slug: "OTHER")).to be(false)
      expect(project.errors[:slug]).to include("can't be changed once the project has items")
    end

    it "still allows renaming a project with items" do
      project = create(:project)
      project.items.create!(title: "An item")

      expect(project.update(name: "Renamed")).to be(true)
    end
  end

  describe "#claim_next_item_number!" do
    it "increments and returns the sequence" do
      project = create(:project)

      expect(project.claim_next_item_number!).to eq(1)
      expect(project.claim_next_item_number!).to eq(2)
      expect(project.reload.last_item_number).to eq(2)
    end
  end
end
