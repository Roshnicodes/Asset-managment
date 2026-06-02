require "test_helper"

class DocumentMasterTest < ActiveSupport::TestCase
  test "destroys linked vendor registration documents when destroyed" do
    document_master = document_masters(:one)

    vendor_registration_document = VendorRegistrationDocument.create!(
      vendor_registration: vendor_registrations(:one),
      document_master: document_master
    )

    assert_difference("DocumentMaster.count", -1) do
      assert_difference("VendorRegistrationDocument.count", -1) do
        assert document_master.destroy
      end
    end

    assert_not VendorRegistrationDocument.exists?(vendor_registration_document.id)
  end
end
