FactoryBot.define do
  factory :project do
    organization
    sequence(:name) { |n| "Project #{n}" }
  end
end
