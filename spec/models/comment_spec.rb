require "rails_helper"

RSpec.describe Comment, type: :model do
  subject { build(:comment) }

  it { is_expected.to belong_to(:item) }
  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_inclusion_of(:source).in_array(Comment::SOURCES) }

  describe "body" do
    it "is required" do
      comment = build(:comment, body: "")

      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to include("can't be blank")
    end

    it "is stored as rich text and round-trips plain and HTML forms" do
      comment = create(:comment, body: "Reproduced on staging")
      comment.reload

      expect(comment.body).to be_a(ActionText::RichText)
      expect(comment.body.to_plain_text).to eq("Reproduced on staging")
      expect(comment.body.to_s).to include("Reproduced on staging")
    end
  end

  describe "source" do
    it "defaults to web" do
      expect(Comment.new.source).to eq("web")
    end

    it "reports api-sourced comments via #from_api?" do
      expect(build(:comment, source: "api")).to be_from_api
      expect(build(:comment, source: "web")).not_to be_from_api
    end
  end
end
