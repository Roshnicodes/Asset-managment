require "active_support/core_ext/integer/time"

Rails.application.configure do
  app_host = ENV["APP_HOST"].presence || Rails.application.credentials.dig(:app, :host).presence || "example.com"
  app_protocol = ENV["APP_PROTOCOL"].presence || Rails.application.credentials.dig(:app, :protocol).presence || "https"
  app_port = ENV["APP_PORT"].presence || Rails.application.credentials.dig(:app, :port).presence

  mailer_url_options = { host: app_host, protocol: app_protocol }
  mailer_url_options[:port] = app_port.to_i if app_port.present?

  smtp_address = ENV["SMTP_ADDRESS"].presence || Rails.application.credentials.dig(:smtp, :address).presence
  smtp_port = ENV["SMTP_PORT"].presence || Rails.application.credentials.dig(:smtp, :port).presence || 587
  smtp_user_name = ENV["SMTP_USERNAME"].presence || Rails.application.credentials.dig(:smtp, :user_name).presence
  smtp_password = ENV["SMTP_PASSWORD"].presence || Rails.application.credentials.dig(:smtp, :password).presence
  smtp_domain = ENV["SMTP_DOMAIN"].presence || Rails.application.credentials.dig(:smtp, :domain).presence || app_host
  smtp_authentication = ENV["SMTP_AUTHENTICATION"].presence || Rails.application.credentials.dig(:smtp, :authentication).presence || "plain"
  smtp_enable_starttls_auto =
    ENV["SMTP_ENABLE_STARTTLS_AUTO"].presence ||
    Rails.application.credentials.dig(:smtp, :enable_starttls_auto)

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false
  config.log_level = :debug 
  config.logger = ActiveSupport::Logger.new(STDOUT)
  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = mailer_url_options
  Rails.application.routes.default_url_options.merge!(mailer_url_options)

  # Configure outgoing email delivery in production
   config.force_ssl = false
  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.

  if smtp_address.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: smtp_port.to_i,
      domain: smtp_domain,
      user_name: smtp_user_name,
      password: smtp_password,
      authentication: smtp_authentication.to_sym,
      enable_starttls_auto: smtp_enable_starttls_auto.nil? ? true : ActiveModel::Type::Boolean.new.cast(smtp_enable_starttls_auto)
    }.compact
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
  config.hosts << "apurti.ploughmanagro.com"
  config.hosts << "168.144.88.192"

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end

