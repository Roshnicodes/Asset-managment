require "test_helper"

class DocumentMasterTest < ActiveSupport::TestCase
  test "cannot be destroyed when linked vendor registration documents exist" do
    document_master = document_masters(:one)

    VendorRegistrationDocument.create!(
      vendor_registration: vendor_registrations(:one),
      document_master: document_master
    )

    assert_not document_master.destroy
    assert_includes document_master.errors.full_messages.to_sentence.downcase, "vendor registration documents"
    assert DocumentMaster.exists?(document_master.id)
  end
end
