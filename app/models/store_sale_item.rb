class StoreSaleItem < ApplicationRecord
  belongs_to :store_sale
  belongs_to :product

  # Validaciones numéricas
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # --- AQUÍ ESTÁ LA MAGIA PARA EVITAR EL ERROR 500 ---
  # Validamos ANTES de crear. Si falla, detiene el proceso y manda alerta.
  validate :check_stock_availability, on: :create

  private

  def check_stock_availability
    # Si no hay producto, salimos (otra validación fallará)
    return unless product.present?

    # Si pides más de lo que hay
    if product.stock < quantity
      errors.add(:base, "Stock insuficiente para '#{product.name}'. Disponible: #{product.stock}, Solicitado: #{quantity}.")
    end
  end
end
