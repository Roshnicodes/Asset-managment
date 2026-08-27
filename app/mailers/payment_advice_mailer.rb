class PaymentAdviceMailer < ApplicationMailer
  LOCAL_FILE_DELIVERY_PATH = Rails.root.join("tmp", "payment_advice_mails").to_s

  def payment_advice
    @payment_advice = params[:payment_advice]

    message = mail(
      to: @payment_advice.payee_email,
      from: self.class.payment_advice_sender,
      subject: "Payment Advice #{@payment_advice.advice_no}"
    )

    if !Rails.env.test? && self.class.payment_advice_smtp_settings.present?
      message.delivery_method(:smtp, self.class.payment_advice_smtp_settings)
    elsif self.class.payment_advice_local_file_delivery?
      message.delivery_method(:file, location: LOCAL_FILE_DELIVERY_PATH)
    end

    message
  end

  def self.payment_advice_delivery_configured?
    payment_advice_real_smtp_configured? || payment_advice_local_file_delivery? || Rails.env.test?
  end

  def self.payment_advice_local_file_delivery?
    ActionMailer::Base.delivery_method == :file
  end

  def self.payment_advice_real_smtp_configured?
    payment_advice_smtp_settings.present?
  end

  def self.payment_advice_sender
    ENV["SMTP_FROM"].presence ||
      ENV["MAILER_SENDER"].presence ||
      Rails.application.credentials.dig(:smtp, :from).presence ||
      payment_advice_smtp_settings[:user_name].presence ||
      "no-reply@example.com"
  end

  def self.payment_advice_smtp_settings
    address = ENV["SMTP_ADDRESS"].presence || Rails.application.credentials.dig(:smtp, :address).presence
    return configured_action_mailer_smtp_settings if address.blank?

    authentication = ENV["SMTP_AUTHENTICATION"].presence || Rails.application.credentials.dig(:smtp, :authentication).presence
    user_name =
      ENV["SMTP_USERNAME"].presence ||
      ENV["SMTP_FROM"].presence ||
      Rails.application.credentials.dig(:smtp, :user_name).presence
    password = ENV["SMTP_PASSWORD"].presence || Rails.application.credentials.dig(:smtp, :password).presence

    {
      address: address,
      port: smtp_port,
      domain: smtp_domain,
      user_name: user_name,
      password: password,
      authentication: authentication.to_s.presence&.to_sym,
      enable_starttls_auto: smtp_starttls_setting,
      ssl: smtp_boolean_setting("SMTP_SSL", :ssl, default: false),
      open_timeout: smtp_timeout_setting("SMTP_OPEN_TIMEOUT", 10),
      read_timeout: smtp_timeout_setting("SMTP_READ_TIMEOUT", 10)
    }.compact
  end

  def self.configured_action_mailer_smtp_settings
    return {} unless ActionMailer::Base.delivery_method == :smtp

    settings = ActionMailer::Base.smtp_settings.symbolize_keys
    address = settings[:address].to_s.strip
    return {} if address.blank? || %w[localhost 127.0.0.1].include?(address)

    settings.compact
  end

  def self.smtp_port
    (ENV["SMTP_PORT"].presence || Rails.application.credentials.dig(:smtp, :port).presence || 587).to_i
  end

  def self.smtp_domain
    ENV["SMTP_DOMAIN"].presence ||
      Rails.application.credentials.dig(:smtp, :domain).presence ||
      ENV["APP_HOST"].presence ||
      Rails.application.credentials.dig(:app, :host).presence ||
      "localhost"
  end

  def self.smtp_boolean_setting(env_key, credential_key, default:)
    raw_value = ENV[env_key].presence || Rails.application.credentials.dig(:smtp, credential_key)
    return default if raw_value.nil?

    ActiveModel::Type::Boolean.new.cast(raw_value)
  end

  def self.smtp_starttls_setting
    raw_value =
      ENV["SMTP_ENABLE_STARTTLS_AUTO"].presence ||
      ENV["SMTP_STARTTLS"].presence ||
      Rails.application.credentials.dig(:smtp, :enable_starttls_auto)
    return true if raw_value.nil?

    ActiveModel::Type::Boolean.new.cast(raw_value)
  end

  def self.smtp_timeout_setting(env_key, default)
    (ENV[env_key].presence || Rails.application.credentials.dig(:smtp, env_key.delete_prefix("SMTP_").downcase.to_sym).presence || default).to_i
  end
end
