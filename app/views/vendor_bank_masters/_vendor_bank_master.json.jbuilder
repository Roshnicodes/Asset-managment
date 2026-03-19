json.extract! vendor_bank_master, :id, :vendor_registration_id, :bank_name, :bank_address, :ifsc_code, :account_number, :account_type, :created_at, :updated_at
json.url vendor_bank_master_url(vendor_bank_master, format: :json)
