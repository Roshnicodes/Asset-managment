class AddBlockToPmus < ActiveRecord::Migration[8.1]
  def change
    add_reference :pmus, :block, foreign_key: true
  end
end
