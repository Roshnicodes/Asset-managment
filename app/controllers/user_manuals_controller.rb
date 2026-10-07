require "base64"
require "open3"

class UserManualsController < ApplicationController
  SUPPORTED_LANGUAGES = %w[en hi].freeze
  WKHTMLTOPDF_COMMAND = ENV.fetch("WKHTMLTOPDF_COMMAND", "wkhtmltopdf").freeze
  MANUAL_IMAGE_ROOT = Rails.root.join("app/assets/images").freeze
  MANUAL_IMAGE_CONTENT_TYPES = {
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".svg" => "image/svg+xml"
  }.freeze

  helper_method :manual_asset_data_uri, :manual_stakeholder_logo_data_uri

  def index
    @manual_language = normalized_language
    @manual_copy = manual_copy_for(@manual_language)
    @manual_stakeholder = current_employee_master&.stakeholder_category
  end

  def download
    @manual_language = normalized_language
    @manual_copy = manual_copy_for(@manual_language)
    @manual_stakeholder = current_employee_master&.stakeholder_category

    pdf_data, error_message = build_manual_pdf
    if pdf_data && pdf_data.bytesize > 0
      send_data(
        pdf_data,
        filename: "asset-management-user-manual-#{@manual_language}.pdf",
        type: "application/pdf",
        disposition: "attachment"
      )
    else
      redirect_to user_manual_path(lang: @manual_language),
                  alert: pdf_generation_alert(error_message)
    end
  end

  private

  def normalized_language
    requested_language = params[:lang].to_s.strip.downcase
    SUPPORTED_LANGUAGES.include?(requested_language) ? requested_language : "en"
  end

  def resolve_wkhtmltopdf_command
    configured = ENV["WKHTMLTOPDF_COMMAND"].to_s.strip
    return configured if configured.present? && File.executable?(configured)

    # Prioritize standard package binary over broken gems/wrappers in /usr/local/bin
    ["/usr/bin/wkhtmltopdf", "/usr/local/bin/wkhtmltopdf"].each do |candidate|
      next unless File.file?(candidate) && File.executable?(candidate)

      first_bytes = begin
        File.read(candidate, 40)
      rescue StandardError
        nil
      end
      next if first_bytes&.include?("ruby")

      return candidate
    end

    configured.presence || "wkhtmltopdf"
  end

  def build_manual_pdf
    html = render_to_string(:download, layout: false, formats: [:html])
    command = resolve_wkhtmltopdf_command

    run_generator = lambda do
      Open3.capture3(
        command,
        "--quiet",
        "--encoding",
        "utf-8",
        "--enable-local-file-access",
        "--page-size",
        "A4",
        "--margin-top",
        "8mm",
        "--margin-right",
        "8mm",
        "--margin-bottom",
        "8mm",
        "--margin-left",
        "8mm",
        "-",
        "-",
        stdin_data: html,
        binmode: true
      )
    end

    output, error, status = if defined?(Bundler)
                              Bundler.with_unbundled_env(&run_generator)
                            else
                              run_generator.call
                            end

    return [output, nil] if status.success? && output && output.bytesize > 0

    [nil, error]
  rescue Errno::ENOENT
    [nil, "wkhtmltopdf command was not found. Please use browser Print / Save PDF."]
  end

  def pdf_generation_alert(error_message)
    fallback_message = "PDF could not be generated. Please use browser Print / Save PDF."
    normalized_error = error_message.to_s.squish
    return fallback_message if normalized_error.blank?

    "#{fallback_message} #{normalized_error.truncate(240)}"
  end

  def manual_asset_data_uri(logical_path)
    requested_path = logical_path.to_s.delete_prefix("/")
    asset_path = MANUAL_IMAGE_ROOT.join(requested_path).cleanpath
    return unless asset_path.to_s.start_with?(MANUAL_IMAGE_ROOT.to_s)
    return unless asset_path.file?

    content_type = MANUAL_IMAGE_CONTENT_TYPES.fetch(asset_path.extname.downcase, "application/octet-stream")
    "data:#{content_type};base64,#{Base64.strict_encode64(asset_path.binread)}"
  end

  def manual_stakeholder_logo_data_uri
    stakeholder = @manual_stakeholder || current_employee_master&.stakeholder_category

    if stakeholder&.logo_file&.attached?
      blob = stakeholder.logo_file.blob
      content_type = blob.content_type.presence || "image/png"
      return "data:#{content_type};base64,#{Base64.strict_encode64(blob.download)}"
    end

    manual_asset_data_uri("asset-logoq.svg")
  end

  # Copy of the manual for one language; screenshots come from the content.
  def manual_copy_for(language)
    copy = UserManualContent.for(language).deep_dup
    copy[:sections].each do |section|
      section[:screenshots] = Array(section[:screenshots]).map { |image, caption| { image: image, caption: caption } }
      section[:image] = section[:screenshots].first&.dig(:image)
      section[:caption] = section[:screenshots].first&.dig(:caption)
    end
    copy
  end

end
