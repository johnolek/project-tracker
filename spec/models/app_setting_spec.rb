require "rails_helper"

RSpec.describe AppSetting do
  describe ".signups_open?" do
    it "honours an explicit true or false over the automatic rules" do
      described_class.instance.update!(allow_signups: false)
      expect(described_class.signups_open?).to be(false)

      described_class.instance.update!(allow_signups: true)
      expect(described_class.signups_open?).to be(true)
    end

    context "when automatic (nil)" do
      it "is open while no accounts exist (fresh-deploy bootstrap)" do
        allow(Rails.env).to receive(:local?).and_return(false)

        expect(described_class.signups_open?).to be(true)
      end

      it "closes in production-like environments once an account exists" do
        create(:user)
        allow(Rails.env).to receive(:local?).and_return(false)

        expect(described_class.signups_open?).to be(false)
      end

      it "stays open in development/test even with accounts" do
        create(:user)

        expect(described_class.signups_open?).to be(true)
      end
    end
  end
end
