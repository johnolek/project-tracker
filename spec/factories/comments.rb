FactoryBot.define do
  factory :comment do
    item
    user
    body { "A comment body" }
  end
end
