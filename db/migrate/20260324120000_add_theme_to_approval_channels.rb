class AddThemeToApprovalChannels < ActiveRecord::Migration[7.0]
  def change
    add_reference :approval_channels, :theme, foreign_key: true, null: true
  end
end
