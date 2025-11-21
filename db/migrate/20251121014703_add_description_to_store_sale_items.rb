class AddDescriptionToStoreSaleItems < ActiveRecord::Migration[7.1]
  def change
    add_column :store_sale_items, :description, :string
  end
end
