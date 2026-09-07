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

  def manual_copy_for(language)
    attach_section_screenshots!(language == "hi" ? hindi_manual_copy : english_manual_copy, language)
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

  def attach_section_screenshots!(copy, language)
    copy[:sections].each do |section|
      screenshots = manual_screenshot_set(section[:id], language)
      section[:screenshots] = screenshots
      section[:image] = screenshots.first[:image]
      section[:caption] = screenshots.first[:caption]
    end

    copy
  end

  def manual_screenshot_set(section_id, language)
    captions = language == "hi" ? hindi_screenshot_captions : english_screenshot_captions
    (captions[section_id] || []).map do |image, caption|
      { image: image, caption: caption }
    end
  end

  def english_screenshot_captions
    {
      "open-manual" => [
        ["manual/manual-dashboard.png", "Manual home with stakeholder logo, language switch, workflow navigation, and PDF download."]
      ],
      "vendor-registration" => [
        ["manual/manual-vendor-registration.png", "Approved ASA vendor registration with company, contact, bank, product, and document details."]
      ],
      "approvals" => [
        ["manual/manual-approval-request.png", "Approval queue and status trail used for approve, return, and reject decisions."]
      ],
      "quotation" => [
        ["manual/manual-quotation-proposal.png", "RFP record with ASA stakeholder, IT Department theme, selected vendors, item details, criteria, and committee."]
      ],
      "vendor-response" => [
        ["manual/manual-vendor-response.png", "Vendor quotation response page after OTP verification with rate, GST, terms, and submit controls."]
      ],
      "comparison-selection" => [
        ["manual/manual-comparison.png", "Committee comparison with three vendor rates, scores, rank, and selected vendor."]
      ],
      "purchase-order" => [
        ["manual/manual-po-create.png", "PO creation screen with Authorized By, Last date, Print Purchase Order, and Send to Vendor action."],
        ["manual/manual-po-vendor.png", "Vendor purchase order screen with ASA/RCI logos and Accept, Return, Reject actions."]
      ],
      "goods-invoice" => [
        ["manual/manual-goods-receive.png", "Goods Receive form with item-wise Yes/No, received quantity, original invoice, and fixed asset fields."],
        ["manual/manual-invoice-upload.png", "Vendor invoice upload screen with OTP-verified upload form and terms acceptance."],
        ["manual/manual-invoice-review.png", "Maker invoice review card with uploaded invoice files, Accept Invoice, and Return Invoice actions."]
      ],
      "finance-assets" => [
        ["manual/manual-asset-create.png", "Asset Creation Workspace opened from the accepted invoice request."],
        ["manual/manual-payment-reference.png", "Accepted invoice selected for PDO/RFP details before moving to finance."],
        ["manual/manual-finance-payment.png", "Finance Payment Queue with selected invoice and transaction details ready to save."]
      ],
      "tips" => [
        ["manual/manual-tips.png", "Final trail showing invoice, asset, finance, and payment status together."]
      ]
    }
  end

  def hindi_screenshot_captions
    {
      "open-manual" => [
        ["manual/manual-dashboard.png", "Stakeholder logo, language switch, workflow navigation और PDF download वाला manual home."]
      ],
      "vendor-registration" => [
        ["manual/manual-vendor-registration.png", "ASA vendor registration जिसमें company, contact, bank, product और document details approved state में हैं."]
      ],
      "approvals" => [
        ["manual/manual-approval-request.png", "Approve, Return और Reject decision के लिए approval queue और status trail."]
      ],
      "quotation" => [
        ["manual/manual-quotation-proposal.png", "ASA stakeholder, IT Department theme, selected vendors, item details, criteria और committee वाला RFP record."]
      ],
      "vendor-response" => [
        ["manual/manual-vendor-response.png", "OTP verification के बाद vendor quotation response page जिसमें rate, GST, terms और submit controls हैं."]
      ],
      "comparison-selection" => [
        ["manual/manual-comparison.png", "तीन vendors के rates, scores, rank और selected vendor वाला committee comparison."]
      ],
      "purchase-order" => [
        ["manual/manual-po-create.png", "Authorized By, Last date, Print Purchase Order और Send to Vendor action वाला PO creation screen."],
        ["manual/manual-po-vendor.png", "ASA/RCI logos और Accept, Return, Reject actions वाला vendor purchase order screen."]
      ],
      "goods-invoice" => [
        ["manual/manual-goods-receive.png", "Item-wise Yes/No, received quantity, original invoice और fixed asset fields वाला Goods Receive form."],
        ["manual/manual-invoice-upload.png", "OTP verified vendor invoice upload screen जिसमें upload form और terms acceptance है."],
        ["manual/manual-invoice-review.png", "Uploaded invoice files, Accept Invoice और Return Invoice actions वाला maker review card."]
      ],
      "finance-assets" => [
        ["manual/manual-asset-create.png", "Accepted invoice request से खुला Asset Creation Workspace."],
        ["manual/manual-payment-reference.png", "Finance में move करने से पहले PDO/RFP details के लिए selected accepted invoice."],
        ["manual/manual-finance-payment.png", "Selected invoice और transaction details के साथ Finance Payment Queue."]
      ],
      "tips" => [
        ["manual/manual-tips.png", "Invoice, asset, finance और payment status को एक साथ दिखाने वाला final trail."]
      ]
    }
  end

  def english_manual_copy
    {
      page_title: "Asset Management User Manual",
      subtitle: "Step-by-step help for vendor registration, quotations, purchase orders, goods receive, invoices, finance payment, and asset creation.",
      updated_label: "Visible after every login",
      stakeholder_label: "Stakeholder",
      module_label: "Procurement workflow",
      download_label: "Download PDF",
      contents_label: "Contents",
      note_label: "Note",
      screenshot_label: "Screenshot",
      screenshot_note: "Use these screen references while following the steps.",
      quick_flow_title: "Full Workflow",
      quick_flow: [
        "Login",
        "Vendor Registration",
        "Approval",
        "Quotation / RFP",
        "Vendor Response",
        "Comparison",
        "Purchase Order",
        "Goods Receive",
        "Invoice",
        "Payment / Assets"
      ],
      language_links: [
        { code: "en", label: "English" },
        { code: "hi", label: "हिंदी" }
      ],
      intro_cards: [
        { title: "For Every User", body: "Open User Manual from the sidebar after login. This page is not restricted by role permissions." },
        { title: "Use Your Own Menu", body: "Some task menus depend on your role. If a menu is missing, contact the admin for access." },
        { title: "Follow Status Badges", body: "Use badges like Pending, Approved, Returned, Sent, Accepted, Uploaded, and Finance Queue to know the next action." }
      ],
      sections: [
        {
          id: "open-manual",
          number: "01",
          title: "Open The Manual And Change Language",
          image: "manual/manual-dashboard.png",
          caption: "Sidebar manual link and language switch.",
          steps: [
            "Login with your Employee Code and password.",
            "Click User Manual at the bottom of the left sidebar. It appears for every signed-in user.",
            "Use the English / हिंदी buttons at the top to change the manual language.",
            "Use the contents links to jump directly to Vendor Registration, Quotation, PO, Invoice, or Finance steps."
          ],
          note: "The manual is for reading only. It does not create, edit, approve, or delete any record."
        },
        {
          id: "vendor-registration",
          number: "02",
          title: "Vendor Registration",
          image: "manual/manual-vendor-registration.png",
          caption: "Vendor Registration Form with step pages and bank/document sections.",
          steps: [
            "Open Vendor Registration Form, then click Vendor Registration.",
            "Fill Basic Information: Stakeholder Name, Firm Name, Vendor Name, and Firm Type.",
            "Fill Contact and Location: GST No, PAN No, Email, Mobile No, Address, State, District, Block, and PIN No.",
            "Select Theme, Product, and Product Type as applicable.",
            "Add bank details and upload required documents such as PAN, MSME, establishment certificate, cancelled cheque, and any configured document.",
            "Click Save. The record will appear in Vendor Registration or Vendor Registration List.",
            "If the record is returned, open Edit, read the return remark, correct the details, and save again."
          ],
          note: "PAN, GST, mobile number, and PIN have format checks. Keep document files clear and readable before upload."
        },
        {
          id: "approvals",
          number: "03",
          title: "Approvals And Returned Corrections",
          image: "manual/manual-approval-request.png",
          caption: "My Approvals, approve/return/reject actions, and status trail.",
          steps: [
            "Open My Approvals from the sidebar when an approval is assigned to you.",
            "Open the pending record and review all details and attachments.",
            "Choose Approve when the details are correct.",
            "Choose Return when the maker must correct details. Always add a clear remark.",
            "Choose Reject only when the request should not continue.",
            "The maker can update returned records and send them back through the same workflow."
          ],
          note: "Only users mapped in the approval channel can act on approvals. Admin users can see broader records."
        },
        {
          id: "quotation",
          number: "04",
          title: "Quotation Proposal / Request For Proposal",
          image: "manual/manual-quotation-proposal.png",
          caption: "Request for Proposal form with vendors, items, criteria, and committee.",
          steps: [
            "Open Quotation Proposal, then click Request for Proposal.",
            "Select Quotation Value: Above 10K or Below 10K.",
            "Select Theme, enter Quotation Subject, Proposal Ending Date, and Proposal Remark.",
            "Select vendors. The vendor list filters by the selected theme.",
            "Add Proposal Items with Item Name, Unit, Quantity, Max Rate, and Remark.",
            "Select Vendor Selection Criteria if the committee should score by defined criteria. Leave blank only when manual scoring is expected.",
            "Add Approval Committee members and click Save Request for Proposal.",
            "After required approvals/committee steps are complete, open the quotation and click Send to Vendors."
          ],
          note: "For Below 10K, the first vendor response may open directly for maker entry. For Above 10K, vendor links are sent to selected vendors."
        },
        {
          id: "vendor-response",
          number: "05",
          title: "Vendor Quotation Response",
          image: "manual/manual-vendor-response.png",
          caption: "Vendor OTP screen and quotation response form.",
          steps: [
            "Vendor opens the quotation SMS link.",
            "Vendor enters OTP and clicks Verify OTP.",
            "Vendor reviews quotation details and enters Vendor Reference No.",
            "Vendor fills item-wise Quoted Rate, GST %, and Remarks.",
            "Vendor adds commercial details such as Payment Terms and Condition, Date of Completion, Warranty Period, and Earnest Money Deposit when requested.",
            "Vendor accepts General Terms and Conditions.",
            "Vendor clicks Submit Response and can print/save the submitted response."
          ],
          note: "If OTP expires, click Send New OTP and verify again before submitting."
        },
        {
          id: "comparison-selection",
          number: "06",
          title: "Comparison, Scoring, And Vendor Selection",
          image: "manual/manual-comparison.png",
          caption: "Vendor comparison, committee score, and selected vendor status.",
          steps: [
            "Open the quotation after vendor responses are submitted.",
            "Review item-wise rates, GST, line totals, grand totals, and vendor remarks.",
            "Committee members enter scores where scoring is required.",
            "Use comparison view/print to check the ranking and selected vendor.",
            "Confirm the selected vendor before moving to Purchase Order."
          ],
          note: "Selection depends on the configured workflow, total values, and committee scoring status."
        },
        {
          id: "purchase-order",
          number: "07",
          title: "Purchase Order",
          image: "manual/manual-po-create.png",
          caption: "Purchase Order page and vendor Accept/Return/Reject response.",
          steps: [
            "Open Quotation Proposal List and click the Purchase Order action for the selected quotation.",
            "Review the PO sheet and select Authorized By if required.",
            "Enter Last date for the vendor response.",
            "Use Print Purchase Order if a print/PDF copy is needed.",
            "Click Send to Vendor. The vendor receives a PO link by SMS.",
            "Vendor opens the link, verifies OTP, reads the PO, enters a remark, accepts terms, and chooses Accept, Return, or Reject.",
            "If the vendor returns the PO, maker or committee can add Reply / Update For Vendor and resend when needed."
          ],
          note: "Return can be used only once by the vendor. After acceptance, the Goods Receive step becomes available."
        },
        {
          id: "goods-invoice",
          number: "08",
          title: "Goods Receive And Invoice Upload",
          image: "manual/manual-goods-receive.png",
          caption: "Goods Receive entry and vendor invoice upload page.",
          steps: [
            "After PO acceptance, open the quotation and click Goods Receive.",
            "For each received item, choose Goods Receive Now as Yes.",
            "Select Original Invoice Receive as Yes or No.",
            "Enter Receive Now Qty. The quantity cannot be more than Pending Qty.",
            "Confirm Fixed Asset Type when applicable and click Submit Goods Receive.",
            "The system creates an invoice upload request and sends the invoice upload link to the vendor.",
            "Vendor opens the invoice link, verifies OTP, uploads invoice files, accepts terms, and clicks Submit Invoice.",
            "Maker reviews the uploaded invoice and chooses Accept Invoice or Return Invoice. Returned invoices can be re-uploaded by the vendor."
          ],
          note: "Each goods receive submission creates a separate invoice request, so partial deliveries can be tracked cleanly."
        },
        {
          id: "finance-assets",
          number: "09",
          title: "Finance Payment And Asset Creation",
          image: "manual/manual-finance-payment.png",
          caption: "Create Assets, send invoices to finance, and Finance Payment Queue.",
          steps: [
            "After the maker accepts an invoice, use Create Assets when the received items are fixed assets.",
            "Create the required asset rows from the accepted invoice request.",
            "From the quotation workflow, select accepted invoices and enter PDO No, RFP No, and RFP Create Date.",
            "Click Move Selected Invoices To Finance.",
            "Finance login opens Payment Advice Queue.",
            "Finance selects invoice requests, fills Transaction Type, Transaction No, and Transaction Date.",
            "Click Save Selected Finance Payment to mark the finance payment update."
          ],
          note: "Finance queue access is role-based. If the queue is not visible for a finance user, check the employee designation/access setup."
        },
        {
          id: "tips",
          number: "10",
          title: "Common Tips",
          image: "manual/manual-tips.png",
          caption: "Quick checks before submitting any task.",
          steps: [
            "Read validation messages at the top or below fields before retrying.",
            "Use clear remarks when returning, rejecting, or replying to a vendor.",
            "Upload readable PDF/JPG/PNG files and verify the file names before submitting.",
            "Do not refresh or close the page until the success message appears.",
            "Check the status badge and response timeline to know who must act next.",
            "Ask the admin to review RBAC/menu access if an expected task menu is missing."
          ],
          note: "When in doubt, open this manual again from the sidebar and follow the relevant section step by step."
        }
      ]
    }
  end

  def hindi_manual_copy
    {
      page_title: "एसेट मैनेजमेंट यूजर मैनुअल",
      subtitle: "Vendor Registration, Quotation, Purchase Order, Goods Receive, Invoice, Finance Payment और Asset Creation के लिए आसान step-by-step guide.",
      updated_label: "हर login के बाद visible",
      stakeholder_label: "Stakeholder",
      module_label: "Procurement workflow",
      download_label: "PDF Download",
      contents_label: "विषय सूची",
      note_label: "नोट",
      screenshot_label: "Screenshot",
      screenshot_note: "Steps follow करते समय इन screen references को देखें.",
      quick_flow_title: "पूरा Workflow",
      quick_flow: [
        "Login",
        "Vendor Registration",
        "Approval",
        "Quotation / RFP",
        "Vendor Response",
        "Comparison",
        "Purchase Order",
        "Goods Receive",
        "Invoice",
        "Payment / Assets"
      ],
      language_links: [
        { code: "en", label: "English" },
        { code: "hi", label: "हिंदी" }
      ],
      intro_cards: [
        { title: "हर User के लिए", body: "Login के बाद sidebar से User Manual खोलें. यह page role permission से restrict नहीं है." },
        { title: "अपना Menu देखें", body: "कुछ task menus role के अनुसार दिखते हैं. अगर कोई menu नहीं दिख रहा है तो admin से access check करवाएं." },
        { title: "Status Badge Follow करें", body: "Pending, Approved, Returned, Sent, Accepted, Uploaded और Finance Queue जैसे badges से next action समझें." }
      ],
      sections: [
        {
          id: "open-manual",
          number: "01",
          title: "Manual खोलना और Language बदलना",
          image: "manual/manual-dashboard.png",
          caption: "Sidebar manual link और language switch.",
          steps: [
            "अपने Employee Code और password से login करें.",
            "Left sidebar में सबसे नीचे User Manual पर click करें. यह हर signed-in user को दिखेगा.",
            "Manual language बदलने के लिए ऊपर English / हिंदी button use करें.",
            "Vendor Registration, Quotation, PO, Invoice या Finance section पर direct जाने के लिए contents links use करें."
          ],
          note: "Manual केवल पढ़ने के लिए है. इससे कोई record create, edit, approve या delete नहीं होता."
        },
        {
          id: "vendor-registration",
          number: "02",
          title: "Vendor Registration",
          image: "manual/manual-vendor-registration.png",
          caption: "Vendor Registration Form, step pages, bank और document sections.",
          steps: [
            "Vendor Registration Form खोलें, फिर Vendor Registration पर click करें.",
            "Basic Information भरें: Stakeholder Name, Firm Name, Vendor Name और Firm Type.",
            "Contact and Location भरें: GST No, PAN No, Email, Mobile No, Address, State, District, Block और PIN No.",
            "Theme, Product और Product Type select करें.",
            "Bank details add करें और PAN, MSME, establishment certificate, cancelled cheque या configured documents upload करें.",
            "Save पर click करें. Record Vendor Registration या Vendor Registration List में दिखेगा.",
            "अगर record Returned है, तो Edit खोलें, return remark पढ़ें, correction करें और फिर Save करें."
          ],
          note: "PAN, GST, mobile number और PIN में format validation है. Upload से पहले documents clear/readable रखें."
        },
        {
          id: "approvals",
          number: "03",
          title: "Approvals और Returned Corrections",
          image: "manual/manual-approval-request.png",
          caption: "My Approvals, approve/return/reject actions और status trail.",
          steps: [
            "जब approval आपके login पर assigned हो, sidebar से My Approvals खोलें.",
            "Pending record open करके details और attachments check करें.",
            "Details सही हों तो Approve करें.",
            "Maker को correction करना हो तो Return करें और clear remark जरूर लिखें.",
            "Request आगे नहीं बढ़ानी हो तभी Reject करें.",
            "Returned record को maker update करके same workflow में फिर आगे भेज सकता है."
          ],
          note: "Approval action केवल approval channel में mapped users कर सकते हैं. Admin users broader records देख सकते हैं."
        },
        {
          id: "quotation",
          number: "04",
          title: "Quotation Proposal / Request For Proposal",
          image: "manual/manual-quotation-proposal.png",
          caption: "Request for Proposal form with vendors, items, criteria और committee.",
          steps: [
            "Quotation Proposal खोलें, फिर Request for Proposal पर click करें.",
            "Quotation Value select करें: Above 10K या Below 10K.",
            "Theme select करें, Quotation Subject, Proposal Ending Date और Proposal Remark भरें.",
            "Vendors select करें. Selected theme के अनुसार vendor list filter होती है.",
            "Proposal Items add करें: Item Name, Unit, Quantity, Max Rate और Remark.",
            "Committee scoring चाहिए तो Vendor Selection Criteria select करें. Manual scoring चाहिए तो criteria blank रखे जा सकते हैं.",
            "Approval Committee members add करें और Save Request for Proposal पर click करें.",
            "Required approvals/committee steps complete होने के बाद quotation open करके Send to Vendors पर click करें."
          ],
          note: "Below 10K में maker direct vendor response entry कर सकता है. Above 10K में selected vendors को links भेजे जाते हैं."
        },
        {
          id: "vendor-response",
          number: "05",
          title: "Vendor Quotation Response",
          image: "manual/manual-vendor-response.png",
          caption: "Vendor OTP screen और quotation response form.",
          steps: [
            "Vendor quotation SMS link open करता है.",
            "Vendor OTP enter करके Verify OTP पर click करता है.",
            "Vendor quotation details review करके Vendor Reference No. भरता है.",
            "Item-wise Quoted Rate, GST % और Remarks भरता है.",
            "जरूरत के अनुसार Payment Terms and Condition, Date of Completion, Warranty Period और Earnest Money Deposit भरता है.",
            "General Terms and Conditions accept करता है.",
            "Submit Response पर click करता है और submitted response print/save कर सकता है."
          ],
          note: "OTP expire होने पर Send New OTP पर click करके फिर verify करें."
        },
        {
          id: "comparison-selection",
          number: "06",
          title: "Comparison, Scoring और Vendor Selection",
          image: "manual/manual-comparison.png",
          caption: "Vendor comparison, committee score और selected vendor status.",
          steps: [
            "Vendor responses submit होने के बाद quotation open करें.",
            "Item-wise rates, GST, line totals, grand totals और vendor remarks review करें.",
            "Scoring required हो तो committee members scores enter करें.",
            "Ranking और selected vendor check करने के लिए comparison view/print use करें.",
            "Purchase Order पर जाने से पहले selected vendor confirm करें."
          ],
          note: "Selection configured workflow, total values और committee scoring status पर depend करता है."
        },
        {
          id: "purchase-order",
          number: "07",
          title: "Purchase Order",
          image: "manual/manual-po-create.png",
          caption: "Purchase Order page और vendor Accept/Return/Reject response.",
          steps: [
            "Quotation Proposal List खोलें और selected quotation के Purchase Order action पर click करें.",
            "PO sheet review करें और जरूरत हो तो Authorized By select करें.",
            "Vendor response के लिए Last date enter करें.",
            "Print/PDF copy चाहिए तो Print Purchase Order use करें.",
            "Send to Vendor पर click करें. Vendor को SMS से PO link मिलेगा.",
            "Vendor link open करके OTP verify करता है, PO पढ़ता है, remark लिखता है, terms accept करता है और Accept, Return या Reject चुनता है.",
            "Vendor PO return करे तो maker या committee Reply / Update For Vendor add करके जरूरत होने पर resend कर सकते हैं."
          ],
          note: "Vendor PO को केवल एक बार Return कर सकता है. Accept होने के बाद Goods Receive step available होता है."
        },
        {
          id: "goods-invoice",
          number: "08",
          title: "Goods Receive और Invoice Upload",
          image: "manual/manual-goods-receive.png",
          caption: "Goods Receive entry और vendor invoice upload page.",
          steps: [
            "PO accepted होने के बाद quotation open करके Goods Receive पर click करें.",
            "Received item के लिए Goods Receive Now में Yes चुनें.",
            "Original Invoice Receive में Yes या No select करें.",
            "Receive Now Qty enter करें. Quantity Pending Qty से ज्यादा नहीं होनी चाहिए.",
            "Fixed Asset Type applicable हो तो confirm करें और Submit Goods Receive पर click करें.",
            "System invoice upload request create करता है और vendor को invoice upload link SMS से भेजता है.",
            "Vendor invoice link open करके OTP verify करता है, invoice files upload करता है, terms accept करता है और Submit Invoice पर click करता है.",
            "Maker uploaded invoice review करके Accept Invoice या Return Invoice choose करता है. Returned invoice vendor फिर से upload कर सकता है."
          ],
          note: "हर goods receive submission separate invoice request बनाता है, इसलिए partial delivery cleanly track होती है."
        },
        {
          id: "finance-assets",
          number: "09",
          title: "Finance Payment और Asset Creation",
          image: "manual/manual-finance-payment.png",
          caption: "Create Assets, invoices को finance में move करना और Finance Payment Queue.",
          steps: [
            "Maker invoice accept करे, उसके बाद received item fixed asset हो तो Create Assets use करें.",
            "Accepted invoice request से required asset rows create करें.",
            "Quotation workflow से accepted invoices select करें और PDO No, RFP No, RFP Create Date भरें.",
            "Move Selected Invoices To Finance पर click करें.",
            "Finance login Payment Advice Queue खोलता है.",
            "Finance invoice requests select करके Transaction Type, Transaction No और Transaction Date भरता है.",
            "Finance payment update mark करने के लिए Save Selected Finance Payment पर click करें."
          ],
          note: "Finance queue access role-based है. Finance user को queue न दिखे तो employee designation/access setup check करें."
        },
        {
          id: "tips",
          number: "10",
          title: "Common Tips",
          image: "manual/manual-tips.png",
          caption: "किसी भी task को submit करने से पहले quick checks.",
          steps: [
            "Retry करने से पहले top या fields के नीचे validation messages पढ़ें.",
            "Vendor को return, reject या reply करते समय clear remark लिखें.",
            "Readable PDF/JPG/PNG files upload करें और submit से पहले file names verify करें.",
            "Success message आने तक page refresh या close न करें.",
            "Next action किसके पास है यह जानने के लिए status badge और response timeline check करें.",
            "Expected task menu missing हो तो admin से RBAC/menu access review करवाएं."
          ],
          note: "Confusion हो तो sidebar से यह manual फिर खोलें और relevant section step by step follow करें."
        }
      ]
    }
  end
end
