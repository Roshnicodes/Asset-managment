class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_SENDER"].presence || Rails.application.credentials.dig(:smtp, :from).presence || "no-reply@example.com"
  layout "mailer"
end
