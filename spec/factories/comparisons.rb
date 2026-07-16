FactoryBot.define do
  factory :comparison do
    transient do
      project { association(:project) }
    end

    item_a { association(:item, project: project) }
    item_b { association(:item, project: project) }
    user
    outcome { "a_wins" }
  end
end
