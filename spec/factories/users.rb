FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    webauthn_id { WebAuthn.generate_user_id }
  end
end
