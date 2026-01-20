class AddScanningUntilToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :scanning_until, :datetime
  end
end
