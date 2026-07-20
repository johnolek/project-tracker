# Instance-wide admin settings (a singleton row), edited at /settings/admin.
# Nothing here is per-organization — these switches govern the deployment.
class AppSetting < ApplicationRecord
  # @return [AppSetting] the singleton row, created on first access
  def self.instance
    first_or_create!
  end

  # Whether /signup is open (PROJ-76). An explicit admin choice wins; the
  # automatic default (allow_signups nil) opens signup only while no accounts
  # exist — so a fresh deploy can bootstrap its first user and then closes
  # itself — and keeps development/test open for tooling that registers
  # throwaway users.
  #
  # @return [Boolean]
  def self.signups_open?
    setting = instance.allow_signups
    return setting unless setting.nil?

    User.none? || Rails.env.local?
  end
end
