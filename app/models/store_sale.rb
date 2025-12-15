class StoreSalesController < ApplicationController
  before_action :authenticate_user!

  # ... (tus otros métodos index, new, etc.) ...

  # POST /store_sales
  def create
    @store_sale = StoreSale.new(store_sale_params)
    @store_sale.user = current_user
    @store_sale.occurred_at ||= Time.current

    # Usamos una transacción para asegurar que todo se guarde o nada
    ActiveRecord::Base.transaction do
      # 1. Intentamos guardar la venta (esto guardará los items también)
      # Si no hay stock, el modelo StoreSaleItem lanzará un error aquí.
      @store_sale.save!

      # 2. Si se guardó, descontamos el stock de los productos
      @store_sale.store_sale_items.each do |item|
        product = item.product
        new_stock = product.stock - item.quantity
        product.update!(stock: new_stock)
      end
    end

    # ÉXITO: Si llegamos aquí, todo salió bien
    redirect_to store_sales_path, notice: "Venta registrada correctamente."

  rescue ActiveRecord::RecordInvalid => e
    # 🛑 AQUÍ ATRAPAMOS EL ERROR 500
    # En lugar de tronar, mostramos el mensaje que escribió el modelo (ej: "Stock insuficiente...")

    # Recargamos productos para que el formulario no se rompa al volver a renderizar
    @products = Product.where(active: true).order(:name)

    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity

  rescue => e
    # Captura cualquier otro error inesperado
    flash.now[:alert] = "Error inesperado: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  private

  # Asegúrate de tener estos params definidos al final de tu archivo
  def store_sale_params
    params.require(:store_sale).permit(
      :payment_method,
      :client_id, # Si asocias clientes a ventas de tienda
      store_sale_items_attributes: [ :product_id, :quantity, :unit_price_cents, :_destroy ]
    )
  end
end
