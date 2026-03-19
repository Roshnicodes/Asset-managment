require "test_helper"

class VendorBankMastersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vendor_bank_master = vendor_bank_masters(:one)
  end

  test "should get index" do
    get vendor_bank_masters_url
    assert_response :success
  end

  test "should get new" do
    get new_vendor_bank_master_url
    assert_response :success
  end

  test "should create vendor_bank_master" do
    assert_difference("VendorBankMaster.count") do
      post vendor_bank_masters_url, params: { vendor_bank_master: { account_number: @vendor_bank_master.account_number, account_type: @vendor_bank_master.account_type, bank_address: @vendor_bank_master.bank_address, bank_name: @vendor_bank_master.bank_name, ifsc_code: @vendor_bank_master.ifsc_code, vendor_registration_id: @vendor_bank_master.vendor_registration_id } }
    end

    assert_redirected_to vendor_bank_master_url(VendorBankMaster.last)
  end

  test "should show vendor_bank_master" do
    get vendor_bank_master_url(@vendor_bank_master)
    assert_response :success
  end

  test "should get edit" do
    get edit_vendor_bank_master_url(@vendor_bank_master)
    assert_response :success
  end

  test "should update vendor_bank_master" do
    patch vendor_bank_master_url(@vendor_bank_master), params: { vendor_bank_master: { account_number: @vendor_bank_master.account_number, account_type: @vendor_bank_master.account_type, bank_address: @vendor_bank_master.bank_address, bank_name: @vendor_bank_master.bank_name, ifsc_code: @vendor_bank_master.ifsc_code, vendor_registration_id: @vendor_bank_master.vendor_registration_id } }
    assert_redirected_to vendor_bank_master_url(@vendor_bank_master)
  end

  test "should destroy vendor_bank_master" do
    assert_difference("VendorBankMaster.count", -1) do
      delete vendor_bank_master_url(@vendor_bank_master)
    end

    assert_redirected_to vendor_bank_masters_url
  end
end
