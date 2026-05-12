require "test_helper"

class VendorRegistrationTest < ActiveSupport::TestCase
  setup do
    @vendor_registration = vendor_registrations(:one)
  end

  test "is valid with correctly formatted gst pan email and mobile" do
    assert @vendor_registration.valid?
  end

  test "requires the core vendor registration fields" do
    @vendor_registration.stakeholder_category = nil
    @vendor_registration.firm_name = ""
    @vendor_registration.vendor_name = ""
    @vendor_registration.firm_type = ""
    @vendor_registration.pan_no = ""
    @vendor_registration.email = ""
    @vendor_registration.mobile_no = ""
    @vendor_registration.state = nil
    @vendor_registration.district = nil
    @vendor_registration.block = nil
    @vendor_registration.pin_no = ""
    @vendor_registration.contact_person_name = ""
    @vendor_registration.contact_person_designation = ""
    @vendor_registration.company_status = ""
    @vendor_registration.firm_profile = ""
    @vendor_registration.business_description = ""
    @vendor_registration.theme_ids = []
    @vendor_registration.product_ids = []
    @vendor_registration.product_variety_ids = []

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:firm_name], "can't be blank"
    assert_includes @vendor_registration.errors[:theme_ids], "must select at least one theme"
    assert_includes @vendor_registration.errors[:product_ids], "must select at least one product"
    assert_includes @vendor_registration.errors[:product_variety_ids], "must select at least one product type"
  end

  test "rejects invalid gst number" do
    @vendor_registration.gst_no = "INVALIDGST"
    @vendor_registration.firm_type = "Company"

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:gst_no], "must be a valid 15-character GST number"
  end

  test "requires gst number when firm type is company" do
    @vendor_registration.firm_type = "Company"
    @vendor_registration.gst_no = ""

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:gst_no], "can't be blank"
  end

  test "does not require gst number when firm type is not company" do
    @vendor_registration.firm_type = "Proprietor"
    @vendor_registration.gst_no = ""

    assert @vendor_registration.valid?
  end

  test "rejects invalid pan number" do
    @vendor_registration.pan_no = "1234ABCDE"

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:pan_no], "must be a valid 10-character PAN number"
  end

  test "rejects invalid email" do
    @vendor_registration.email = "wrong-email"

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:email], "must be a valid email address"
  end

  test "rejects invalid indian mobile number" do
    @vendor_registration.mobile_no = "5123456789"

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:mobile_no], "must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9"
  end

  test "rejects invalid pin code" do
    @vendor_registration.pin_no = "01234"

    assert_not @vendor_registration.valid?
    assert_includes @vendor_registration.errors[:pin_no], "must be a valid 6-digit PIN code"
  end

  test "normalizes gst pan email and mobile before validation" do
    @vendor_registration.gst_no = "27abcde1234f1z5"
    @vendor_registration.pan_no = "abcde1234f"
    @vendor_registration.email = "  VENDOR@EXAMPLE.COM "
    @vendor_registration.mobile_no = "98 765-43210"
    @vendor_registration.pin_no = "221 001"

    @vendor_registration.valid?

    assert_equal "27ABCDE1234F1Z5", @vendor_registration.gst_no
    assert_equal "ABCDE1234F", @vendor_registration.pan_no
    assert_equal "vendor@example.com", @vendor_registration.email
    assert_equal "9876543210", @vendor_registration.mobile_no
    assert_equal "221001", @vendor_registration.pin_no
  end
end
