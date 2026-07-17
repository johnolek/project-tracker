FactoryBot.define do
  factory :api_key do
    user
    organization { user.default_organization }
    sequence(:name) { |n| "Key #{n}" }
  end
end
