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

  describe "changing the slug" do
    it "allows changing the slug while the project has no items" do
      project = create(:project)

      expect(project.update(slug: "FRESH")).to be(true)
    end

    it "allows changing the slug once items exist, retiring the old slug" do
      project = create(:project, slug: "OLD")
      project.items.create!(title: "An item")

      expect(project.update(slug: "NEW")).to be(true)
      expect(project.reload.slug).to eq("NEW")
      expect(project.slug_aliases.pluck(:slug)).to include("OLD")
    end

    it "reserves a retired slug against reuse by another project" do
      org = create(:organization)
      create(:project, organization: org, slug: "OLD").update!(slug: "NEW")

      reused = build(:project, organization: org, slug: "OLD")
      expect(reused).not_to be_valid
      expect(reused.errors[:slug]).to include("is reserved by another project")
    end

    it "lets a project reclaim its own retired slug" do
      project = create(:project, slug: "OLD")
      project.update!(slug: "NEW")

      expect(project.update(slug: "OLD")).to be(true)
      expect(project.slug_aliases.where("lower(slug) = ?", "old")).to be_empty
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
