FactoryBot.define do
  factory :item_type do
    organization
    sequence(:name) { |n| "type-#{n}" }
    color { "#3273dc" }
    sequence(:position) { |n| n }
  end
end
