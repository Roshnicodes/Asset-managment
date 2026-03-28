class AddFirmToDocumentMasters < ActiveRecord::Migration[8.1]
  def change
    add_reference :document_masters, :firm, foreign_key: true
  end
end
