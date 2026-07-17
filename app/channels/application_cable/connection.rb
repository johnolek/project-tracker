module ApplicationCable
  # Cable subscribers must be signed in: every channel is org-scoped, and the
  # anonymous public board that once justified open connections is gone.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user || reject_unauthorized_connection
    end

    private

    # @return [User, nil]
    def find_verified_user
      session = cookies.encrypted[Rails.application.config.session_options.fetch(:key)]
      User.find_by(id: session&.[]("user_id"))
    end
  end
end
