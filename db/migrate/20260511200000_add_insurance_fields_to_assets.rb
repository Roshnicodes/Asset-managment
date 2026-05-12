class AddInsuranceFieldsToAssets < ActiveRecord::Migration[8.1]
  def change
    change_table :assets, bulk: true do |t|
      t.boolean :insured
      t.string :insurance_company_name
      t.string :insurance_policy_number
      t.date :insurance_expiry_date
    end
  end
end
