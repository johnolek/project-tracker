FactoryBot.define do
  factory :membership do
    user
    organization
    role { "owner" }
  end
end
