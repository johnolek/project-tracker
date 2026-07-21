FactoryBot.define do
  factory :embed_domain do
    organization
    project { association :project, organization: organization }
    sequence(:host) { |n| "host#{n}.example.com" }
  end
end
