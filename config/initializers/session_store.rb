# Persist the session across browser restarts with a rolling 30-day window.
# Without this, Rails uses a browser-session cookie that is dropped when the
# browser closes — which reads as being logged out constantly.
Rails.application.config.session_store :cookie_store,
                                       key: "_project_tracker_session",
                                       expire_after: 30.days
