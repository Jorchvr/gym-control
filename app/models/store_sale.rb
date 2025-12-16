class StoreSale < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true

  # Relación con los productos vendidos
  has_many :store_sale_items, dependent: :destroy
  accepts_nested_attributes_for :store_sale_items, allow_destroy: true

  # Validaciones
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
end
