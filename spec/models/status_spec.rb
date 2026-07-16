require "rails_helper"

RSpec.describe Status, type: :model do
  subject { build(:status) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:items).dependent(:restrict_with_error) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer }
  it { is_expected.to validate_inclusion_of(:category).in_array(Status::CATEGORIES) }
end
