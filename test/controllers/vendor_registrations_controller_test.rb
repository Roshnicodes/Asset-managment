require "test_helper"

class VendorRegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vendor_registration = vendor_registrations(:one)
  end

  test "should get index" do
    get vendor_registrations_url
    assert_response :success
  end

  test "should get new" do
    get new_vendor_registration_url
    assert_response :success
  end

  test "should create vendor_registration" do
    assert_difference("VendorRegistration.count") do
      post vendor_registrations_url, params: { vendor_registration: { block_id: @vendor_registration.block_id, business_description: @vendor_registration.business_description, company_name: @vendor_registration.company_name, company_status: @vendor_registration.company_status, contact_person_designation: @vendor_registration.contact_person_designation, contact_person_name: @vendor_registration.contact_person_name, district_id: @vendor_registration.district_id, email: @vendor_registration.email, firm_id: @vendor_registration.firm_id, firm_type: @vendor_registration.firm_type, gst_no: @vendor_registration.gst_no, mobile_no: @vendor_registration.mobile_no, msme: @vendor_registration.msme, msme_number: @vendor_registration.msme_number, pan_no: @vendor_registration.pan_no, pin_no: @vendor_registration.pin_no, registration_type_id: @vendor_registration.registration_type_id, state_id: @vendor_registration.state_id, submitted_at: @vendor_registration.submitted_at, submitted_ip: @vendor_registration.submitted_ip, vendor_name: @vendor_registration.vendor_name } }
    end

    assert_redirected_to vendor_registration_url(VendorRegistration.last)
  end

  test "should show vendor_registration" do
    get vendor_registration_url(@vendor_registration)
    assert_response :success
  end

  test "should get edit" do
    get edit_vendor_registration_url(@vendor_registration)
    assert_response :success
  end

  test "should update vendor_registration" do
    patch vendor_registration_url(@vendor_registration), params: { vendor_registration: { block_id: @vendor_registration.block_id, business_description: @vendor_registration.business_description, company_name: @vendor_registration.company_name, company_status: @vendor_registration.company_status, contact_person_designation: @vendor_registration.contact_person_designation, contact_person_name: @vendor_registration.contact_person_name, district_id: @vendor_registration.district_id, email: @vendor_registration.email, firm_id: @vendor_registration.firm_id, firm_type: @vendor_registration.firm_type, gst_no: @vendor_registration.gst_no, mobile_no: @vendor_registration.mobile_no, msme: @vendor_registration.msme, msme_number: @vendor_registration.msme_number, pan_no: @vendor_registration.pan_no, pin_no: @vendor_registration.pin_no, registration_type_id: @vendor_registration.registration_type_id, state_id: @vendor_registration.state_id, submitted_at: @vendor_registration.submitted_at, submitted_ip: @vendor_registration.submitted_ip, vendor_name: @vendor_registration.vendor_name } }
    assert_redirected_to vendor_registration_url(@vendor_registration)
  end

  test "should destroy vendor_registration" do
    assert_difference("VendorRegistration.count", -1) do
      delete vendor_registration_url(@vendor_registration)
    end

    assert_redirected_to vendor_registrations_url
  end
end
