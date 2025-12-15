class StoreSale < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true

  # Relación con los items (productos) de la venta
  # dependent: :destroy asegura que si borras la venta, se borren sus items
  has_many :store_sale_items, dependent: :destroy

  # Esto es vital para que el formulario de venta funcione
  accepts_nested_attributes_for :store_sale_items, allow_destroy: true

  # Validaciones
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
end
