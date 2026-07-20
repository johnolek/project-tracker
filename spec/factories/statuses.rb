FactoryBot.define do
  factory :status do
    organization
    sequence(:name) { |n| "Status #{n}" }
    # Offset past the default statuses every organization is seeded with
    # (positions 1..4) so factory rows never trip position uniqueness.
    sequence(:position) { |n| n + 100 }
    category { "open" }
  end
end
