FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    webauthn_id { WebAuthn.generate_user_id }

    # Factory users are verified by default (setting email_verified_at directly
    # sidesteps the reset-on-email-change callback). Pass email_verified: false
    # for a pending, unverified account.
    transient do
      email_verified { true }
    end

    after(:create) do |user, evaluator|
      user.update_column(:email_verified_at, Time.current) if evaluator.email_verified
    end
  end
end
