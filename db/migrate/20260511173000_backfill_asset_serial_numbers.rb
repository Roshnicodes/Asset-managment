class BackfillAssetSerialNumbers < ActiveRecord::Migration[8.1]
  class Asset < ApplicationRecord
    self.table_name = "assets"
  end

  def up
    next_serial_number = Asset.where("serial_number ~ '^[0-9]+$'")
      .order(Arel.sql("CAST(serial_number AS BIGINT) DESC"))
      .limit(1)
      .pick(:serial_number)
      .to_i + 1

    Asset.where(serial_number: [nil, ""]).order(:id).find_each do |asset|
      asset.update_columns(serial_number: next_serial_number.to_s)
      next_serial_number += 1
    end
  end

  def down
    # Existing blank serial numbers are backfilled intentionally.
  end
end
