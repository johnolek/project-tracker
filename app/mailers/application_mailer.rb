class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "recovery@localhost")
  layout "mailer"
end
