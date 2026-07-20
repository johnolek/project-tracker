require "rails_helper"

# The type/points/tags filter core is mirrored in JS (item_filters.js) and here
# (ComparisonsController#matches_filters?). Both suites run the same case table
# (spec/fixtures/filter_cases.json — also exercised by
# spec/javascript/item_filters.test.js via `yarn test`) so the two sides can't
# drift silently (PROJ-79).
RSpec.describe ComparisonsController, type: :controller do
  fixture = JSON.parse(File.read(Rails.root.join("spec/fixtures/filter_cases.json")))

  tag_stub = Struct.new(:name)
  item_stub = Struct.new(:item_type, :points, :tags, :status_id)

  fixture.fetch("cases").each do |filter_case|
    it filter_case.fetch("name") do
      filters = filter_case.fetch("filters")
      controller.params = ActionController::Parameters.new(
        item_type: filters["item_type"],
        min_points: filters["min_points"],
        max_points: filters["max_points"],
        tags: filters["tags"] || []
      )
      allow(controller).to receive_messages(
        requested_status_ids: [],
        item_type_names: [ filter_case.dig("item", "item_type"), filters["item_type"] ].compact.uniq
      )

      item = item_stub.new(
        filter_case.dig("item", "item_type"),
        filter_case.dig("item", "points"),
        (filter_case.dig("item", "tags") || []).map { |name| tag_stub.new(name) },
        1
      )

      expect(controller.send(:matches_filters?, item)).to be(filter_case.fetch("expected"))
    end
  end
end
