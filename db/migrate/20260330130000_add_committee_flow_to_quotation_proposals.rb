class AddCommitteeFlowToQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:quotation_proposals, :workflow_status)
      add_column :quotation_proposals, :workflow_status, :string, null: false, default: "committee_pending"
    end

    add_column :quotation_proposals, :sent_to_vendors_at, :datetime unless column_exists?(:quotation_proposals, :sent_to_vendors_at)

    unless column_exists?(:quotation_proposals, :selected_vendor_registration_id)
      add_reference :quotation_proposals, :selected_vendor_registration, foreign_key: { to_table: :vendor_registrations }
    end

    unless column_exists?(:quotation_proposal_vendors, :response_status)
      add_column :quotation_proposal_vendors, :response_status, :string, null: false, default: "pending"
    end

    add_column :quotation_proposal_vendors, :vendor_remark, :text unless column_exists?(:quotation_proposal_vendors, :vendor_remark)
    add_column :quotation_proposal_vendors, :responded_at, :datetime unless column_exists?(:quotation_proposal_vendors, :responded_at)
    add_column :quotation_proposal_vendors, :committee_score, :integer unless column_exists?(:quotation_proposal_vendors, :committee_score)
    add_column :quotation_proposal_vendors, :rank_position, :integer unless column_exists?(:quotation_proposal_vendors, :rank_position)

    unless column_exists?(:quotation_proposal_vendors, :selected)
      add_column :quotation_proposal_vendors, :selected, :boolean, null: false, default: false
    end

    unless table_exists?(:quotation_proposal_committee_steps)
      create_table :quotation_proposal_committee_steps do |t|
        t.references :quotation_proposal, null: false, foreign_key: true
        t.references :employee_master, null: false, foreign_key: true
        t.integer :level, null: false
        t.string :status, null: false, default: "pending"
        t.text :remark
        t.datetime :actioned_at

        t.timestamps
      end
    end

    unless index_exists?(:quotation_proposal_committee_steps, [:quotation_proposal_id, :level], unique: true, name: "idx_qp_committee_steps_on_proposal_and_level")
      add_index :quotation_proposal_committee_steps,
                [:quotation_proposal_id, :level],
                unique: true,
                name: "idx_qp_committee_steps_on_proposal_and_level"
    end

    unless table_exists?(:quotation_proposal_vendor_items)
      create_table :quotation_proposal_vendor_items do |t|
        t.references :quotation_proposal_vendor, null: false, foreign_key: true
        t.references :quotation_proposal_item, null: false, foreign_key: true
        t.decimal :quoted_rate, precision: 12, scale: 2
        t.text :remark

        t.timestamps
      end
    end

    unless index_exists?(:quotation_proposal_vendor_items, [:quotation_proposal_vendor_id, :quotation_proposal_item_id], unique: true, name: "idx_qp_vendor_items_on_vendor_and_item")
      add_index :quotation_proposal_vendor_items,
                [:quotation_proposal_vendor_id, :quotation_proposal_item_id],
                unique: true,
                name: "idx_qp_vendor_items_on_vendor_and_item"
    end
  end
end
