class AddFingerprintToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :fingerprint, :text
  end
end
