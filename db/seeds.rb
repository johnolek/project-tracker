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
  elsif user.default_organization.projects.exists?(name: "Ledgerline")
    puts "Seeds skipped: demo data already present."
  else
    organization = user.default_organization
    statuses = organization.statuses.ordered.group_by(&:category).transform_values(&:first)

    # Rows are [title, type, points, status category, tags, notes (optional)].
    demo_projects = {
      "Ledgerline" => [
        [ "Proration is off by a day on mid-cycle plan changes", "bug", 5, "open", %w[billing backend],
          "<p>Upgrades on the last day of a cycle credit a full day too much. Suspect the billing anchor is computed in UTC while the tenant clock is local.</p>" ],
        [ "Usage-based metering for the API plan", "feature", 8, "open", %w[billing backend] ],
        [ "Stripe webhook retries create duplicate invoices", "bug", 5, "open", %w[billing stripe],
          "<p>When Stripe retries a delayed webhook we finalize twice. Options:</p><ul><li>store the event id and no-op on replay</li><li>make invoice finalization idempotent by period</li></ul>" ],
        [ "Self-serve plan downgrade flow", "feature", 5, "open", %w[frontend billing] ],
        [ "Dunning emails for failed payments", "feature", 3, "open", %w[billing email] ],
        [ "MRR chart loads slowly for large accounts", "bug", 3, "open", %w[frontend perf] ],
        [ "SAML SSO for the enterprise tier", "feature", 8, "open", %w[auth security] ],
        [ "Export invoices to CSV", "feature", 2, "open", %w[frontend quick-win] ],
        [ "Rate-limit the public API per key", "feature", 3, "open", %w[api security] ],
        [ "Annual-plan discount calculator on the pricing page", "idea", 3, "open", %w[frontend ux] ],
        [ "Webhook signature verification is skipped in staging", "bug", 2, "open", %w[security backend] ],
        [ "Timezone selector in account settings", "feature", 2, "open", %w[frontend ux quick-win] ],
        [ "Sandbox mode with test card numbers", "idea", 5, "open", %w[api testing] ],
        [ "Invoice PDF renders the wrong currency symbol for EUR", "bug", 2, "open", %w[billing i18n] ],
        [ "Audit log for admin actions", "feature", 5, "open", %w[security backend] ],
        [ "Seed script for demo tenants", "feature", 2, "open", %w[backend testing] ],
        [ "Migrate the billing tables to a partitioned schema", "feature", 8, "in_progress", %w[db infra],
          "<p>Invoices and line items are the hot tables. Partition by month, backfill in batches, cut over behind a feature flag.</p>" ],
        [ "React 19 upgrade", "feature", 5, "in_progress", %w[frontend] ],
        [ "Refactor the subscription state machine", "feature", 5, "in_progress", %w[backend billing] ],
        [ "Idempotency keys on the charge endpoint", "feature", 3, "in_progress", %w[api billing] ],
        [ "Flaky checkout Cypress spec", "bug", 2, "in_progress", %w[frontend testing] ],
        [ "Upgrade to the 2024-06 Stripe API version", "feature", 3, "done", %w[billing stripe] ],
        [ "Add Sentry error tracking", "feature", 2, "done", %w[infra] ],
        [ "Password reset email has a broken link", "bug", 1, "done", %w[email quick-win] ],
        [ "Dockerize the API service", "feature", 3, "done", %w[infra] ],
        [ "Write the onboarding docs", "feature", 2, "done", %w[docs] ]
      ],
      "Cadence" => [
        [ "GPS track drifts when the app backgrounds on iOS", "bug", 8, "open", %w[ios gps],
          "<p>Points scatter after ~2 minutes backgrounded. Likely losing the significant-location update; verify the always-on permission and the background modes plist.</p>" ],
        [ "Apple Watch companion app", "feature", 8, "open", %w[watch ios] ],
        [ "Interval workout builder", "feature", 5, "open", %w[ui gps] ],
        [ "Splits screen janks on mid-range Android devices", "bug", 3, "open", %w[android performance] ],
        [ "Offline route caching", "feature", 5, "open", %w[offline gps] ],
        [ "Streak reminder push notifications", "feature", 3, "open", %w[notifications quick-win] ],
        [ "Elevation gain double-counts on out-and-back routes", "bug", 3, "open", %w[gps] ],
        [ "Dark mode for the activity feed", "feature", 2, "open", %w[ui design] ],
        [ "Ghost-runner pace comparison", "idea", 5, "open", %w[gps ui] ],
        [ "Heart rate zones from a Bluetooth strap", "feature", 5, "open", %w[ios android] ],
        [ "Battery drains 30% per hour with the screen on", "bug", 5, "open", %w[battery performance],
          "<p>Screen-on runs are the worst. Suspects: 1Hz GPS polling, the live map redraw, and the wake lock never releasing on pause.</p>" ],
        [ "Share a run as an image card", "feature", 3, "open", %w[ui quick-win] ],
        [ "Audio coaching cues", "idea", 3, "open", %w[notifications] ],
        [ "Permission-priming onboarding screen", "feature", 2, "open", %w[ui design] ],
        [ "Sync conflicts when logging a run on two devices", "bug", 5, "open", %w[sync] ],
        [ "Metric/imperial unit toggle", "feature", 1, "open", %w[ui quick-win] ],
        [ "HealthKit and Google Fit integration", "feature", 8, "in_progress", %w[ios android sync] ],
        [ "Rewrite the map renderer on MapLibre", "feature", 8, "in_progress", %w[gps performance] ],
        [ "Crash on resume after a long background", "bug", 5, "in_progress", %w[ios] ],
        [ "Weekly summary email", "feature", 3, "in_progress", %w[notifications] ],
        [ "Migrate to the new navigation stack", "feature", 3, "in_progress", %w[ui] ],
        [ "Fix pace calculation for sub-minute splits", "bug", 2, "done", %w[gps] ],
        [ "Add a TestFlight beta channel", "feature", 2, "done", %w[ios] ],
        [ "App icon redesign", "feature", 1, "done", %w[design] ],
        [ "Set up Detox end-to-end tests", "feature", 3, "done", %w[testing] ],
        [ "Onboarding tutorial", "feature", 2, "done", %w[ui] ]
      ],
      "sift" => [
        [ "Streaming mode blocks on stdin without a trailing newline", "bug", 5, "open", %w[cli parser],
          "<p>A pipe that never sends a newline hangs forever. Flush partial lines on EOF and on a short idle timeout.</p>" ],
        [ "JSON output format", "feature", 3, "open", %w[output] ],
        [ "Regex engine is 4x slower than ripgrep on large files", "bug", 8, "open", %w[regex performance],
          "<p>Profiling points at the hot path doing per-byte work:</p><ul><li>no SIMD literal prefilter</li><li>we recompile the DFA per file</li></ul>" ],
        [ "Windows path handling breaks --glob", "bug", 3, "open", %w[cross-platform] ],
        [ "Config file support (~/.siftrc)", "feature", 5, "open", %w[config] ],
        [ "Colorized output respects NO_COLOR", "feature", 1, "open", %w[output quick-win] ],
        [ "Fuzzy match mode", "idea", 5, "open", %w[regex] ],
        [ "Generate a man page from the clap definition", "feature", 2, "open", %w[docs packaging] ],
        [ "Homebrew formula", "feature", 2, "open", %w[packaging] ],
        [ "--context flag like grep -C", "feature", 3, "open", %w[cli] ],
        [ "Watch mode that re-runs on file change", "idea", 5, "open", %w[cli] ],
        [ "Panics on invalid UTF-8 in binary files", "bug", 3, "open", %w[parser] ],
        [ "Benchmark suite in CI", "feature", 3, "open", %w[ci tests] ],
        [ "Add a --version long form with build info", "feature", 1, "open", %w[good-first-issue quick-win] ],
        [ "Multiline pattern matching", "feature", 8, "open", %w[regex] ],
        [ "Shell completions for zsh and fish", "feature", 2, "open", %w[packaging cli] ],
        [ "Parallelize directory traversal with rayon", "feature", 8, "in_progress", %w[performance] ],
        [ "Migrate the arg parser to clap 4", "feature", 5, "in_progress", %w[cli] ],
        [ "Memory-map large files instead of buffered reads", "feature", 5, "in_progress", %w[performance parser] ],
        [ "Flaky test on the CI Windows runner", "bug", 2, "in_progress", %w[ci cross-platform] ],
        [ "Document the plugin API", "feature", 3, "in_progress", %w[docs] ],
        [ "Set up the GitHub Actions release pipeline", "feature", 3, "done", %w[ci packaging] ],
        [ "Add an --ignore-case flag", "feature", 1, "done", %w[cli] ],
        [ "Fix an off-by-one in reported line numbers", "bug", 1, "done", %w[parser] ],
        [ "MIT license and CONTRIBUTING.md", "feature", 1, "done", %w[docs] ],
        [ "Cross-compile aarch64 binaries", "feature", 3, "done", %w[packaging cross-platform] ]
      ],
      "Beacon" => [
        [ "Consumer lag spikes during traffic bursts", "bug", 8, "open", %w[kafka performance],
          "<p>Lag climbs to millions on spikes and never fully drains. Partition count, consumer concurrency, and downstream write throughput are all suspects.</p>" ],
        [ "Schema registry for event validation", "feature", 8, "open", %w[schema ingestion] ],
        [ "Dedup events by idempotency key", "feature", 5, "open", %w[ingestion] ],
        [ "ClickHouse disk usage grows 5% every week", "bug", 5, "open", %w[clickhouse cost],
          "<p>Growth outpaces event volume. Likely culprits:</p><ul><li>no TTL on raw event tables</li><li>parts never merging on the cold partitions</li></ul>" ],
        [ "Dead-letter queue for malformed events", "feature", 5, "open", %w[ingestion kafka] ],
        [ "Grafana dashboard for pipeline health", "feature", 3, "open", %w[monitoring] ],
        [ "Backfill job for the Q1 ingestion gap", "feature", 5, "open", %w[backfill] ],
        [ "PII scrubbing in the ingestion layer", "feature", 8, "open", %w[security ingestion] ],
        [ "Sampling for high-volume event types", "idea", 5, "open", %w[cost ingestion] ],
        [ "Terraform drift on the MSK cluster", "bug", 3, "open", %w[terraform infra] ],
        [ "Late-arriving events break the daily rollup", "bug", 5, "open", %w[clickhouse schema] ],
        [ "Alert on consumer-group rebalance storms", "feature", 3, "open", %w[alerting monitoring] ],
        [ "Replay tool for reprocessing a topic", "idea", 5, "open", %w[kafka] ],
        [ "dbt model for funnel analysis", "feature", 3, "open", %w[dbt] ],
        [ "Cost dashboard per event source", "feature", 3, "open", %w[cost monitoring] ],
        [ "Compress the cold partitions", "feature", 2, "open", %w[clickhouse cost quick-win] ],
        [ "Migrate ingestion from Kafka Connect to Flink", "feature", 8, "in_progress", %w[kafka ingestion] ],
        [ "Exactly-once semantics on the ClickHouse sink", "feature", 8, "in_progress", %w[ingestion clickhouse] ],
        [ "Partition ClickHouse tables by day", "feature", 5, "in_progress", %w[clickhouse performance] ],
        [ "Autoscale consumers on lag", "feature", 5, "in_progress", %w[infra kafka] ],
        [ "Flaky integration-test container", "bug", 2, "in_progress", %w[ci infra] ],
        [ "Upgrade ClickHouse to 24.3", "feature", 3, "done", %w[clickhouse] ],
        [ "Add Prometheus metrics to the consumers", "feature", 2, "done", %w[monitoring] ],
        [ "Fix a timezone bug in the daily rollup", "bug", 2, "done", %w[schema] ],
        [ "Document the event schema", "feature", 2, "done", %w[docs] ],
        [ "Stand up the staging Kafka cluster", "feature", 3, "done", %w[infra terraform] ]
      ],
      "Nightjar" => [
        [ "Player clips through moving platforms at high speed", "bug", 5, "open", %w[physics gameplay],
          "<p>Fast descent tunnels the collider straight through the platform. Needs continuous collision or a swept cast on the vertical axis.</p>" ],
        [ "Boss fight phase-two mechanics", "feature", 8, "open", %w[gameplay ai] ],
        [ "Controller support in the menus", "feature", 3, "open", %w[input controller] ],
        [ "Enemy pathfinding stalls on diagonal gaps", "bug", 5, "open", %w[ai physics] ],
        [ "Parallax background for the forest level", "feature", 3, "open", %w[art] ],
        [ "Save system with multiple slots", "feature", 5, "open", %w[save-system] ],
        [ "Dash ability with i-frames", "idea", 5, "open", %w[gameplay] ],
        [ "Ambient audio layers per biome", "feature", 3, "open", %w[audio] ],
        [ "Frame drops in the swamp level", "bug", 5, "open", %w[performance],
          "<p>Dips to 40fps near the water. Suspects:</p><ul><li>overlapping transparent particles</li><li>the water shader sampling the full screen texture</li></ul>" ],
        [ "Coyote time on jumps", "feature", 2, "open", %w[gameplay polish] ],
        [ "New Game+ mode", "idea", 8, "open", %w[gameplay] ],
        [ "Water shader for the underground lake", "feature", 5, "open", %w[shaders art] ],
        [ "Remap keys in the options menu", "feature", 3, "open", %w[input ui] ],
        [ "Screen shake on heavy hits", "feature", 1, "open", %w[polish quick-win] ],
        [ "Dialogue box text overflows on long lines", "bug", 2, "open", %w[ui] ],
        [ "Checkpoint flags don't persist after death", "bug", 3, "open", %w[save-system] ],
        [ "Rewrite the tilemap collision layer", "feature", 8, "in_progress", %w[physics] ],
        [ "First pass on the soundtrack", "feature", 5, "in_progress", %w[audio] ],
        [ "Build the second-act village level", "feature", 8, "in_progress", %w[level-design] ],
        [ "Enemy spawner tuning", "feature", 3, "in_progress", %w[gameplay ai] ],
        [ "Audio latency on the web export", "bug", 3, "in_progress", %w[audio performance] ],
        [ "Player movement and jump feel", "feature", 5, "done", %w[gameplay] ],
        [ "Main menu and title screen", "feature", 2, "done", %w[ui art] ],
        [ "Fix the double-jump exploit", "bug", 2, "done", %w[gameplay] ],
        [ "Set up the Godot CI export pipeline", "feature", 3, "done", %w[ci export] ],
        [ "Placeholder art for the enemies", "feature", 1, "done", %w[art] ]
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
