require "rqrcode"

module QrCodesHelper
  def qr_code_svg(content, module_size: 4)
    qr = RQRCode::QRCode.new(content)
    qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: module_size,
      standalone: true,
      use_path: true
    ).html_safe
  end
end
