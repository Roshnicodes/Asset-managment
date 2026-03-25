class CreateQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :quotation_proposals do |t|
      t.references :theme, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :subject, null: false
      t.date :proposal_end_date, null: false
      t.text :remark

      t.timestamps
    end

    create_table :quotation_proposal_vendors do |t|
      t.references :quotation_proposal, null: false, foreign_key: true
      t.references :vendor_registration, null: false, foreign_key: true

      t.timestamps
    end

    add_index :quotation_proposal_vendors, [:quotation_proposal_id, :vendor_registration_id], unique: true, name: "idx_quote_proposal_vendors_unique"

    create_table :quotation_proposal_items do |t|
      t.references :quotation_proposal, null: false, foreign_key: true
      t.string :item_name, null: false
      t.references :unit, null: false, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 2, null: false, default: 0
      t.text :remark

      t.timestamps
    end
  end
end
