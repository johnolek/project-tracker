require "rails_helper"

RSpec.describe ApiKey, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to validate_presence_of(:name) }

  describe "token generation" do
    it "generates a prefixed token on create, readable via #token on the fresh instance" do
      api_key = create(:api_key)

      expect(api_key.token).to start_with(ApiKey::TOKEN_PREFIX)
      expect(api_key.token.length).to eq(ApiKey::TOKEN_PREFIX.length + 32)
    end

    it "persists the digest but not the plaintext" do
      api_key = create(:api_key)
      plaintext = api_key.token
      reloaded = described_class.find(api_key.id)

      expect(reloaded.token).to be_nil
      expect(reloaded.token_digest).to eq(Digest::SHA256.hexdigest(plaintext))
      expect(reloaded.attributes.values).not_to include(plaintext)
    end

    it "stores the last 4 characters of the token" do
      api_key = create(:api_key)

      expect(api_key.last4).to eq(api_key.token.last(4))
    end
  end

  describe ".authenticate" do
    it "returns the key matching the plaintext token" do
      api_key = create(:api_key)

      expect(described_class.authenticate(api_key.token)).to eq(api_key)
    end

    it "returns nil for an unknown token" do
      create(:api_key)

      expect(described_class.authenticate("pt_definitelywrong")).to be_nil
    end

    it "returns nil for nil" do
      expect(described_class.authenticate(nil)).to be_nil
    end

    it "returns nil for an empty string" do
      expect(described_class.authenticate("")).to be_nil
    end
  end

  describe "#touch_last_used" do
    it "sets last_used_at when it has never been used" do
      api_key = create(:api_key)

      expect { api_key.touch_last_used }
        .to change { api_key.reload.last_used_at }.from(nil)
    end

    it "updates last_used_at when the last use is stale" do
      api_key = create(:api_key)
      api_key.update_column(:last_used_at, 5.minutes.ago)

      expect { api_key.touch_last_used }
        .to change { api_key.reload.last_used_at }
    end

    it "skips the write when the last use is under 60 seconds old" do
      api_key = create(:api_key)
      api_key.update_column(:last_used_at, 10.seconds.ago)

      expect { api_key.touch_last_used }
        .not_to change { api_key.reload.last_used_at }
    end
  end
end
