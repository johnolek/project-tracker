module ApplicationCable
  # Anonymous connections are allowed: the public project board subscribes to a
  # signed Turbo Stream name, so no logged-in user is required to receive updates.
  class Connection < ActionCable::Connection::Base
  end
end
