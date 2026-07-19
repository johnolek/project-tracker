# Make the SMTP2GO HTTP API available as an ActionMailer delivery method.
# Selected in config/environments/production.rb when SMTP2GO_API_KEY is set.
# Registered in a to_prepare hook so the autoloaded Smtp2goDelivery constant
# resolves after Zeitwerk is ready (not during initializer boot).
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method :smtp2go, Smtp2goDelivery
end
