FactoryBot.define do
  factory :item_link do
    transient do
      project { association(:project) }
    end

    source { association(:item, project: project) }
    target { association(:item, project: project) }
    kind { "blocks" }
  end
end
