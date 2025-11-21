# db/migrate/20251121014703_add_description_to_store_sale_items.rb
class AddDescriptionToStoreSaleItems < ActiveRecord::Migration[7.1]
  def change
    add_column :store_sale_items, :description, :string
  end
end
