# app/controllers/griselle_cart_controller.rb
class GriselleCartController < ApplicationController
  before_action :authenticate_user!

  # Helpers simples para normalizar el carrito en sesión
  def current_cart
    raw = session[:griselle_cart] || []
    raw = raw.is_a?(Array) ? raw : []
    raw.map { |l| l.is_a?(Hash) ? l.symbolize_keys : l }
  end

  def save_cart!(cart)
    session[:griselle_cart] = cart
  end

  def show
    @cart = current_cart
  end

  # Solo usamos el flujo "custom" (el de tu formulario)
  def add
    if params[:id] == "custom"
      desc      = params[:description].to_s.strip
      amt_cents = ((BigDecimal(params[:amount].to_s) rescue 0) * 100).to_i

      if desc.blank? || amt_cents <= 0
        redirect_to griselle_cart_path, alert: "Ingresa descripción y monto válidos."
        return
      end

      cart = current_cart
      cart << {
        id: SecureRandom.uuid,
        type: "custom",
        name: desc,
        price_cents: amt_cents,
        qty: 1
      }
      save_cart!(cart)
      redirect_to griselle_cart_path, notice: "Agregado."
    else
      # Si algún día reactivas botones rápidos por product_id, se tolera aquí:
      pid = params[:id].to_i
      product = Product.find_by(id: pid)
      unless product
        redirect_to griselle_cart_path, alert: "Producto no encontrado."
        return
      end

      cart = current_cart
      if (line = cart.find { |l| l[:type] == "product" && l[:product_id].to_i == pid })
        line[:qty] = line[:qty].to_i + 1
      else
        cart << {
          id: SecureRandom.uuid,
          type: "product",
          product_id: pid,
          name: product.name,
          price_cents: product.price_cents.to_i,
          qty: 1
        }
      end
      save_cart!(cart)
      redirect_to griselle_cart_path, notice: "Agregado."
    end
  end

  def increment
    line_id = params[:line_id].to_s
    cart = current_cart
    if (line = cart.find { |l| l[:id].to_s == line_id })
      line[:qty] = line[:qty].to_i + 1
    end
    save_cart!(cart)
    redirect_to griselle_cart_path
  end

  def decrement
    line_id = params[:line_id].to_s
    cart = current_cart
    if (line = cart.find { |l| l[:id].to_s == line_id })
      new_qty = line[:qty].to_i - 1
      if new_qty > 0
        line[:qty] = new_qty
      else
        cart.delete(line)
      end
    end
    save_cart!(cart)
    redirect_to griselle_cart_path
  end

  def remove
    line_id = params[:line_id].to_s
    cart = current_cart
    cart.reject! { |l| l[:id].to_s == line_id }
    save_cart!(cart)
    redirect_to griselle_cart_path
  end

  def checkout
    cart = current_cart
    if cart.blank?
      redirect_to griselle_cart_path, alert: "No hay items en el carrito."
      return
    end

    payment_method = params[:payment_method].in?(%w[cash transfer]) ? params[:payment_method] : "cash"

    total_cents = 0
    ss = StoreSale.create!(
      user: current_user,
      payment_method: payment_method,
      total_cents: 0,           # se actualiza al final
      occurred_at: Time.current
    )

    # Producto genérico para servicios de Griselle (sin SKU, sin tocar stock)
    generic_service = Product.find_or_create_by!(name: "Servicio Griselle") do |p|
      p.price_cents = 0
      p.stock = 0
    end

    cart.each do |l|
      qty  = l[:qty].to_i
      unit = l[:price_cents].to_i
      next if qty <= 0 || unit <= 0

      case l[:type]
      when "custom"
        ss.store_sale_items.create!(
          product_id:       generic_service.id,
          quantity:         qty,
          unit_price_cents: unit,
          description:      l[:name] # ← aquí guardamos la descripción que escribes
        )
        # No alteramos stock en servicios

      when "product"
        product = Product.find_by(id: l[:product_id])
        next unless product
        ss.store_sale_items.create!(
          product_id:       product.id,
          quantity:         qty,
          unit_price_cents: unit
        )
        # Si NO quieres tocar stock de productos, deja comentada la línea siguiente
        # product.update!(stock: [product.stock.to_i - qty, 0].max)
      end

      total_cents += unit * qty
    end

    ss.update!(total_cents: total_cents)

    save_cart!([])
    redirect_to griselle_cart_path, notice: "Venta registrada."
  rescue => e
    redirect_to griselle_cart_path, alert: "No se pudo realizar el cobro: #{e.message}"
  end
end
