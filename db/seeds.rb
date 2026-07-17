# Development-only demo data for clicking around the board, search, and the
# prioritize/priorities flow. Auth is passkey-only, so seeds cannot create a
# signable user: register through the browser first, then run bin/rails db:seed
# to fill your organization. Targets SEED_USER=<username> when given, otherwise
# the oldest user that has a passkey. Safe to re-run (skips once present).

if Rails.env.development?
  user = if ENV["SEED_USER"]
    User.find_by!(username: ENV["SEED_USER"])
  else
    User.joins(:credentials).order(:created_at).first
  end

  if user.nil?
    puts "Seeds skipped: no users with a passkey yet. Sign up at /signup, then run bin/rails db:seed."
  elsif user.default_organization.projects.exists?(name: "Cactus Garden Planner")
    puts "Seeds skipped: demo data already present."
  else
    organization = user.default_organization
    statuses = organization.statuses.index_by(&:category)

    demo_projects = {
      "Cactus Garden Planner" => [
        { title: "Drip emitters clog after two weeks", type: "bug", points: 2, tags: %w[water maintenance], status: "in_progress",
          notes: "<p>Every emitter on the east bed slows to a dribble. Suspects:</p><ul><li>hard water scale</li><li>algae in the supply line</li></ul>" },
        { title: "Water the saguaro on a schedule", type: "task", points: 2, tags: %w[garden quick-win], status: "open",
          notes: "<p>Once a month in summer, none in winter. It sulks when overwatered.</p>" },
        { title: "Build the adobe planter wall", type: "task", points: 8, tags: %w[construction], status: "in_progress",
          notes: "<p>Three courses high along the south fence. Bricks are curing.</p>" },
        { title: "Map irrigation lines", type: "task", points: 5, tags: %w[garden infra], status: "open",
          notes: "<p>Nobody remembers where the 1998 PVC runs. Trace before digging anywhere.</p>" },
        { title: "Squirrels keep stealing prickly pear fruit", type: "bug", points: 3, tags: %w[garden wildlife], status: "open" },
        { title: "Solar path lighting along the arroyo", type: "enhancement", points: 5, tags: %w[outdoor electrical], status: "open" },
        { title: "Rainwater catchment estimator", type: "idea", points: 8, tags: %w[water planning], status: "open",
          notes: "<p>Roof area &times; monsoon average = tank size. Spreadsheet first, app later.</p>" },
        { title: "Shade sail over the seedling bench", type: "enhancement", points: 3, tags: %w[outdoor], status: "open" },
        { title: "Order heirloom chile seeds", type: "task", points: 1, tags: %w[garden], status: "done" },
        { title: "Compost bin temperature log", type: "task", points: 2, tags: %w[garden maintenance], status: "done" }
      ],
      "Salsa Lab" => [
        { title: "Roast tomatillos for verde base", type: "task", points: 1, tags: %w[kitchen], status: "in_progress" },
        { title: "Fermented habanero batch #4", type: "task", points: 3, tags: %w[kitchen], status: "open",
          notes: "<p>Batch #3 was too salty. Drop brine to 3%.</p>" },
        { title: "Label designs for gift jars", type: "idea", points: 2, tags: %w[kitchen design], status: "open" },
        { title: "Compare vinegar brands", type: "task", points: 1, tags: %w[kitchen], status: "done" }
      ]
    }

    items_by_title = {}
    demo_projects.each do |project_name, rows|
      project = organization.projects.create!(name: project_name)
      rows.each do |row|
        items_by_title[row[:title]] = project.items.create!(
          title: row[:title],
          item_type: row[:type],
          points: row[:points],
          status: statuses.fetch(row[:status]),
          tag_names: row[:tags],
          notes: row[:notes]
        )
      end
    end

    demo_comparisons = [
      [ "Drip emitters clog after two weeks", "Water the saguaro on a schedule", "a_wins" ],
      [ "Drip emitters clog after two weeks", "Build the adobe planter wall", "a_wins" ],
      [ "Drip emitters clog after two weeks", "Squirrels keep stealing prickly pear fruit", "a_wins" ],
      [ "Water the saguaro on a schedule", "Map irrigation lines", "a_wins" ],
      [ "Water the saguaro on a schedule", "Solar path lighting along the arroyo", "a_wins" ],
      [ "Water the saguaro on a schedule", "Label designs for gift jars", "a_wins" ],
      [ "Build the adobe planter wall", "Squirrels keep stealing prickly pear fruit", "a_wins" ],
      [ "Build the adobe planter wall", "Shade sail over the seedling bench", "a_wins" ],
      [ "Map irrigation lines", "Rainwater catchment estimator", "a_wins" ],
      [ "Map irrigation lines", "Label designs for gift jars", "a_wins" ],
      [ "Squirrels keep stealing prickly pear fruit", "Solar path lighting along the arroyo", "a_wins" ],
      [ "Roast tomatillos for verde base", "Fermented habanero batch #4", "a_wins" ],
      [ "Rainwater catchment estimator", "Solar path lighting along the arroyo", "draw" ],
      [ "Shade sail over the seedling bench", "Fermented habanero batch #4", "draw" ]
    ]

    demo_comparisons.each do |item_a_title, item_b_title, outcome|
      Comparison.create!(
        item_a: items_by_title.fetch(item_a_title),
        item_b: items_by_title.fetch(item_b_title),
        user: user,
        outcome: outcome
      )
    end

    puts "Seeded #{items_by_title.size} items across #{demo_projects.size} projects " \
         "and #{demo_comparisons.size} comparisons into #{organization.name}."
  end
end
