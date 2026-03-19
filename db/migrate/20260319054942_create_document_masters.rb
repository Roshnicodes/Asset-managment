class CreateDocumentMasters < ActiveRecord::Migration[8.1]
  def change
    create_table :document_masters do |t|
      t.string :name

      t.timestamps
    end
  end
end
