FactoryBot.define do
  factory :item do
    project
    sequence(:title) { |n| "Item #{n}" }
    notes { "Some notes" }
    item_type { "task" }
    source { "internal" }

    # status is left to Item#assign_default_status (the org's first open status)
    # unless a spec overrides it explicitly.
  end
end
