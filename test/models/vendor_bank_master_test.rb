require "test_helper"

class VendorBankMasterTest < ActiveSupport::TestCase
  setup do
    @vendor_bank_master = vendor_bank_masters(:one)
  end

  test "is valid with correct ifsc and account number" do
    assert @vendor_bank_master.valid?
  end

  test "rejects invalid ifsc code" do
    @vendor_bank_master.ifsc_code = "123INVALID"

    assert_not @vendor_bank_master.valid?
    assert_includes @vendor_bank_master.errors[:ifsc_code], "must be a valid IFSC code"
  end

  test "rejects invalid account number" do
    @vendor_bank_master.account_number = "12AB34"

    assert_not @vendor_bank_master.valid?
    assert_includes @vendor_bank_master.errors[:account_number], "must be a valid account number"
  end

  test "normalizes ifsc and account number before validation" do
    @vendor_bank_master.ifsc_code = "sbin0001234"
    @vendor_bank_master.account_number = "1234 5678 9012"

    @vendor_bank_master.valid?

    assert_equal "SBIN0001234", @vendor_bank_master.ifsc_code
    assert_equal "123456789012", @vendor_bank_master.account_number
  end
end
