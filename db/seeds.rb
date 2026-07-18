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
    statuses = organization.statuses.ordered.group_by(&:category).transform_values(&:first)

    # Rows are [title, type, points, status category, tags, notes (optional)].
    demo_projects = {
      "Cactus Garden Planner" => [
        [ "Water the saguaro on a schedule", "feature", 2, "open", %w[garden quick-win],
          "<p>Once a month in summer, none in winter. It sulks when overwatered.</p>" ],
        [ "Map irrigation lines", "feature", 5, "open", %w[garden infra],
          "<p>Nobody remembers where the 1998 PVC runs. Trace before digging anywhere.</p>" ],
        [ "Squirrels keep stealing prickly pear fruit", "bug", 3, "open", %w[garden wildlife] ],
        [ "Solar path lighting along the arroyo", "feature", 5, "open", %w[outdoor electrical] ],
        [ "Rainwater catchment estimator", "idea", 8, "open", %w[water planning],
          "<p>Roof area &times; monsoon average = tank size. Spreadsheet first, app later.</p>" ],
        [ "Shade sail over the seedling bench", "feature", 3, "open", %w[outdoor] ],
        [ "Replace cracked olla pots", "feature", 2, "open", %w[garden water] ],
        [ "Gravel path from gate to ramada", "feature", 5, "open", %w[outdoor construction] ],
        [ "Agave pups need transplanting", "feature", 1, "open", %w[garden quick-win] ],
        [ "Javelina-proof the compost enclosure", "feature", 5, "open", %w[wildlife construction] ],
        [ "Frost cloth plan for January", "feature", 2, "open", %w[garden planning] ],
        [ "Label every bed with QR plant tags", "idea", 3, "open", %w[garden design] ],
        [ "Mesquite pod harvest and milling", "idea", 5, "open", %w[garden kitchen] ],
        [ "Drip timer battery dies weekly", "bug", 1, "open", %w[water maintenance] ],
        [ "Wind knocked over the ocotillo trellis", "bug", 3, "open", %w[outdoor] ],
        [ "Native pollinator strip along the fence", "feature", 5, "open", %w[garden wildlife] ],
        [ "Drip emitters clog after two weeks", "bug", 2, "in_progress", %w[water maintenance],
          "<p>Every emitter on the east bed slows to a dribble. Suspects:</p><ul><li>hard water scale</li><li>algae in the supply line</li></ul>" ],
        [ "Build the adobe planter wall", "feature", 8, "in_progress", %w[construction],
          "<p>Three courses high along the south fence. Bricks are curing.</p>" ],
        [ "Grade the swale before monsoon", "feature", 5, "in_progress", %w[water outdoor] ],
        [ "Repot the barrel cactus collection", "feature", 3, "in_progress", %w[garden] ],
        [ "Amend soil in the north bed", "feature", 2, "in_progress", %w[garden maintenance] ],
        [ "Order heirloom chile seeds", "feature", 1, "done", %w[garden] ],
        [ "Compost bin temperature log", "feature", 2, "done", %w[garden maintenance] ],
        [ "Fix the leaning gate post", "bug", 3, "done", %w[construction] ],
        [ "Sketch the spring planting layout", "feature", 2, "done", %w[planning design] ],
        [ "Clean and oil the pruning tools", "feature", 1, "done", %w[maintenance quick-win] ]
      ],
      "Salsa Lab" => [
        [ "Fermented habanero batch #4", "feature", 3, "open", %w[kitchen],
          "<p>Batch #3 was too salty. Drop brine to 3%.</p>" ],
        [ "Label designs for gift jars", "idea", 2, "open", %w[kitchen design] ],
        [ "Smoke test: chipotle en adobo from scratch", "idea", 5, "open", %w[kitchen] ],
        [ "Salsa verde shelf-life experiment", "feature", 3, "open", %w[kitchen testing] ],
        [ "pH meter calibration routine", "feature", 1, "open", %w[kitchen testing quick-win] ],
        [ "Mango habanero ratio still too sweet", "bug", 2, "open", %w[kitchen recipe] ],
        [ "Source local tomatillos in bulk", "feature", 2, "open", %w[kitchen sourcing] ],
        [ "Water-bath canning workflow", "feature", 5, "open", %w[kitchen process] ],
        [ "Ghost pepper micro-batch", "idea", 3, "open", %w[kitchen] ],
        [ "Spice heat rating card for the label", "idea", 2, "open", %w[design] ],
        [ "Blender overheats on double batches", "bug", 2, "open", %w[equipment] ],
        [ "Roasting tray warps at high broil", "bug", 1, "open", %w[equipment] ],
        [ "Neighborhood taste-test scorecards", "idea", 2, "open", %w[testing design] ],
        [ "Roast tomatillos for verde base", "feature", 1, "in_progress", %w[kitchen] ],
        [ "Batch codes and dating system", "feature", 2, "in_progress", %w[process] ],
        [ "Reduce salt in the house red", "feature", 1, "in_progress", %w[recipe] ],
        [ "Photo setup for the label shoot", "feature", 3, "in_progress", %w[design] ],
        [ "Sterilize the new jar shipment", "feature", 1, "in_progress", %w[process quick-win] ],
        [ "Compare vinegar brands", "feature", 1, "done", %w[kitchen] ],
        [ "First verde batch notes", "feature", 1, "done", %w[recipe] ],
        [ "Order 8 oz jars", "feature", 1, "done", %w[sourcing] ],
        [ "Heat-tolerance survey of the family", "idea", 1, "done", %w[testing] ]
      ],
      "Casita Remodel" => [
        [ "Saltillo tile for the entryway", "feature", 8, "open", %w[flooring] ],
        [ "Swamp cooler pads before June", "feature", 2, "open", %w[hvac maintenance quick-win] ],
        [ "Kitchen faucet drips at the base", "bug", 2, "open", %w[plumbing] ],
        [ "Paint the front door turquoise", "feature", 2, "open", %w[paint design] ],
        [ "Viga beam inspection", "feature", 3, "open", %w[structure] ],
        [ "Replace the water heater anode rod", "feature", 2, "open", %w[plumbing maintenance] ],
        [ "Kiva fireplace draft problem", "bug", 5, "open", %w[hvac structure],
          "<p>Smoke rolls back into the room unless a window is cracked. Chimney height? Damper?</p>" ],
        [ "Courtyard string lights", "feature", 2, "open", %w[electrical outdoor] ],
        [ "Skylight in the hallway", "idea", 8, "open", %w[structure design] ],
        [ "Nicho shelf in the reading corner", "idea", 3, "open", %w[design] ],
        [ "Weatherstrip the casita door", "feature", 1, "open", %w[hvac quick-win] ],
        [ "Re-mud the exterior east wall", "feature", 8, "open", %w[structure] ],
        [ "GFCI outlets for the bathroom", "feature", 3, "open", %w[electrical safety] ],
        [ "Closet doors stick in summer", "bug", 2, "open", %w[carpentry] ],
        [ "Talavera backsplash behind the stove", "feature", 5, "open", %w[design kitchen] ],
        [ "Tile the guest bath floor", "feature", 8, "in_progress", %w[flooring] ],
        [ "Patch roof parapet cracks", "feature", 5, "in_progress", %w[structure maintenance] ],
        [ "Strip paint off the interior brick", "feature", 5, "in_progress", %w[paint] ],
        [ "Rewire the porch light switch", "feature", 2, "in_progress", %w[electrical] ],
        [ "Level the bedroom floor", "feature", 5, "in_progress", %w[flooring structure] ],
        [ "Grout color test patches", "feature", 1, "in_progress", %w[flooring design] ],
        [ "Demo the old laundry shelving", "feature", 2, "done", %w[carpentry] ],
        [ "Pick exterior stucco color", "feature", 1, "done", %w[paint design] ],
        [ "Fix the doorbell transformer", "bug", 1, "done", %w[electrical] ],
        [ "Measure every window for screens", "feature", 1, "done", %w[planning] ],
        [ "Haul away the old swamp cooler", "feature", 1, "done", %w[hvac] ]
      ],
      "Trail Rig Overhaul" => [
        [ "Rebuild the front locking hubs", "feature", 5, "open", %w[drivetrain] ],
        [ "Death wobble above 55 mph", "bug", 8, "open", %w[suspension safety],
          "<p>Started after the track bar swap. Check bar torque, then ball joints, then tie rod ends.</p>" ],
        [ "Wire the dual battery isolator", "feature", 5, "open", %w[electrical] ],
        [ "Roof rack rattle on washboard roads", "bug", 2, "open", %w[exterior] ],
        [ "Skid plate for the transfer case", "feature", 5, "open", %w[armor] ],
        [ "Onboard air compressor mount", "feature", 3, "open", %w[recovery] ],
        [ "Recovery point rating check", "feature", 2, "open", %w[recovery safety quick-win] ],
        [ "Map lights for the rear seats", "idea", 2, "open", %w[interior electrical] ],
        [ "Spare tire carrier redesign", "idea", 8, "open", %w[exterior] ],
        [ "Coolant temp spikes on long climbs", "bug", 5, "open", %w[engine] ],
        [ "Fridge slide for the cargo area", "feature", 5, "open", %w[interior camping] ],
        [ "Ham radio antenna mount", "idea", 3, "open", %w[electrical comms] ],
        [ "Re-gear for 35s", "idea", 8, "open", %w[drivetrain] ],
        [ "Sand down and repaint the rock rash", "feature", 3, "open", %w[exterior] ],
        [ "Replace the leaking pinion seal", "feature", 3, "in_progress", %w[drivetrain] ],
        [ "Install the new shock absorbers", "feature", 5, "in_progress", %w[suspension] ],
        [ "LED light bar wiring harness", "feature", 2, "in_progress", %w[electrical] ],
        [ "Bleed the brakes after the line swap", "feature", 2, "in_progress", %w[safety] ],
        [ "Fabricate the rear bumper", "feature", 8, "in_progress", %w[armor exterior] ],
        [ "Oil change and diff fluid", "feature", 1, "done", %w[maintenance] ],
        [ "Mount the new all-terrains", "feature", 2, "done", %w[exterior] ],
        [ "Fix the horn relay", "bug", 1, "done", %w[electrical] ],
        [ "Order the lift kit", "feature", 1, "done", %w[suspension] ],
        [ "Weigh the rig fully loaded", "feature", 1, "done", %w[planning] ]
      ],
      "Pottery Studio" => [
        [ "Kiln element replacement", "feature", 5, "open", %w[kiln equipment] ],
        [ "Glaze test tiles for the new cone 6 set", "feature", 3, "open", %w[glaze testing] ],
        [ "Wedging table height is wrong", "bug", 2, "open", %w[studio ergonomics] ],
        [ "Reclaim bucket system for clay scraps", "feature", 3, "open", %w[studio process] ],
        [ "Slab roller canvas replacement", "feature", 2, "open", %w[equipment maintenance] ],
        [ "Turquoise crawl glaze investigation", "idea", 3, "open", %w[glaze],
          "<p>The accidental crawl on the last batch looked great. Reproduce it on purpose.</p>" ],
        [ "Studio ventilation for glaze spraying", "feature", 8, "open", %w[safety studio] ],
        [ "Pit firing weekend plan", "idea", 5, "open", %w[firing planning] ],
        [ "Mica clay body experiments", "idea", 5, "open", %w[clay testing] ],
        [ "Shelving for greenware near the window", "feature", 3, "open", %w[studio storage] ],
        [ "Wheel pedal sticks at low speed", "bug", 2, "open", %w[equipment] ],
        [ "Price list for the winter market", "feature", 2, "open", %w[business quick-win] ],
        [ "Horsehair raku demo prep", "idea", 3, "open", %w[firing] ],
        [ "Throw the dinner plate commission", "feature", 5, "in_progress", %w[wheel commission] ],
        [ "Trim and handle the mug batch", "feature", 3, "in_progress", %w[wheel] ],
        [ "Mix a 10-gallon batch of white slip", "feature", 2, "in_progress", %w[glaze] ],
        [ "Photograph inventory for the site", "feature", 3, "in_progress", %w[business] ],
        [ "Fire the bisque load", "feature", 2, "done", %w[kiln firing] ],
        [ "Order cone packs", "feature", 1, "done", %w[kiln sourcing] ],
        [ "Fix the wobbly banding wheel", "bug", 1, "done", %w[equipment] ],
        [ "Glaze the test mugs", "feature", 2, "done", %w[glaze] ],
        [ "Clean the studio floor trap", "feature", 1, "done", %w[studio maintenance] ]
      ]
    }

    open_items_by_project = Hash.new { |hash, key| hash[key] = [] }
    item_count = 0
    demo_projects.each do |project_name, rows|
      project = organization.projects.create!(name: project_name)
      rows.each do |title, type, points, status_category, tags, notes|
        item = project.items.create!(
          title: title,
          item_type: type,
          points: points,
          status: statuses.fetch(status_category),
          tag_names: tags,
          notes: notes
        )
        item_count += 1
        open_items_by_project[project_name] << item unless status_category == "done"
      end
    end

    # Comparisons stay within a project (prioritization is project-scoped) and
    # are sampled against a hidden per-item priority so the fitted Bradley-Terry
    # ranking comes out plausible but noisy (with a few upsets and draws).
    # insert_all skips the per-comparison recompute callback; one explicit
    # recompute at the end persists the strengths.
    rng = Random.new(20_260_717)
    now = Time.current

    comparison_rows = open_items_by_project.values.flat_map do |open_items|
      hidden = open_items.shuffle(random: rng)
                         .each_with_index.to_h { |item, index| [ item.id, Math.exp(-0.2 * index) ] }

      Array.new(32) do
        item_a, item_b = open_items.sample(2, random: rng)
        outcome =
          if rng.rand < 0.05
            "draw"
          elsif rng.rand < hidden[item_a.id] / (hidden[item_a.id] + hidden[item_b.id])
            "a_wins"
          else
            "b_wins"
          end
        { item_a_id: item_a.id, item_b_id: item_b.id, user_id: user.id,
          outcome: outcome, created_at: now, updated_at: now }
      end
    end

    Comparison.insert_all(comparison_rows)
    Item.recompute_strengths(organization: organization)

    puts "Seeded #{item_count} items across #{demo_projects.size} projects " \
         "and #{comparison_rows.size} comparisons into #{organization.name}."
  end
end
