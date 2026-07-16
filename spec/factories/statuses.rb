FactoryBot.define do
  factory :status do
    organization
    sequence(:name) { |n| "Status #{n}" }
    sequence(:position) { |n| n }
    category { "open" }
  end
end
