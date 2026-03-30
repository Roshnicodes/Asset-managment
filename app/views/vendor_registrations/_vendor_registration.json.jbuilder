json.extract! vendor_registration, :id, :registration_type_id, :firm_name, :firm_id, :vendor_name, :firm_type, :gst_no, :pan_no, :email, :mobile_no, :state_id, :district_id, :block_id, :pin_no, :contact_person_name, :contact_person_designation, :msme, :msme_number, :company_status, :firm_profile, :business_description, :submitted_at, :submitted_ip, :created_at, :updated_at
json.msme_certificate_url(vendor_registration.msme_certificate.attached? ? rails_blob_url(vendor_registration.msme_certificate, disposition: "attachment") : nil)
json.pan_document_url(vendor_registration.pan_document.attached? ? rails_blob_url(vendor_registration.pan_document, disposition: "attachment") : nil)
json.aadhar_document_url(vendor_registration.aadhar_document.attached? ? rails_blob_url(vendor_registration.aadhar_document, disposition: "attachment") : nil)
json.establishment_certificate_url(vendor_registration.establishment_certificate.attached? ? rails_blob_url(vendor_registration.establishment_certificate, disposition: "attachment") : nil)
json.url vendor_registration_url(vendor_registration, format: :json)
