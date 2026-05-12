class AddInsuranceDateToAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :assets, :insurance_date, :date
  end
end
