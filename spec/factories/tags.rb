FactoryBot.define do
  factory :tag do
    organization
    sequence(:name) { |n| "tag-#{n}" }
  end
end
