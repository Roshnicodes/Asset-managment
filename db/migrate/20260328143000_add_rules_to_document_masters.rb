class AddRulesToDocumentMasters < ActiveRecord::Migration[8.1]
  def change
    add_column :document_masters, :document_key, :string
    add_column :document_masters, :mandatory, :boolean, default: false, null: false
    add_column :document_masters, :proprietor_only, :boolean, default: false, null: false
    add_column :document_masters, :msme_only, :boolean, default: false, null: false
  end
end
