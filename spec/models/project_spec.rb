require "rails_helper"

RSpec.describe Project, type: :model do
  subject { build(:project) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:items).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }

  describe "public_token" do
    it "is generated on creation" do
      project = create(:project)
      expect(project.public_token).to be_present
    end

    it "is unique across projects" do
      first = create(:project)
      second = create(:project)
      expect(first.public_token).not_to eq(second.public_token)
    end
  end
end
