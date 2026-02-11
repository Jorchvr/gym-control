require "base64"

class Api::V1::SyncController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    # 1. CLIENTES
    clientes_data = Client.all.map do |c|
      # --- CORRECCIÓN DE HUELLA ---
      huella_final = nil

      if c.fingerprint.present?
        raw = c.fingerprint

        # Detectamos si Postgres nos dio una cadena Hexadecimal (empieza con \x)
        if raw.is_a?(String) && raw.start_with?("\\x")
          # Convertimos de Hexadecimal String a Binario Puro
          # [2..-1] quita el "\x" del principio
          # pack('H*') convierte los pares de letras/numeros a bytes reales
          raw = [ raw[2..-1] ].pack("H*")
        end

        # Ahora sí, convertimos el binario limpio a Base64
        huella_final = Base64.strict_encode64(raw)
      end
      # ----------------------------

      {
        id: c.id,
        name: c.name,
        fingerprint_template: huella_final, # Usamos la huella corregida
        expiration_date: c.next_payment_on,
        registration_date: c.created_at,
        photo_path: c.photo.attached? ? url_for(c.photo) : nil
      }
    end

    # 2. PRODUCTOS
    productos_data = Product.all.map do |p|
      {
        id: p.id,
        name: p.name,
        price: p.price_cents.to_f / 100.0,
        stock: p.stock
      }
    end

    # 3. USUARIOS
    usuarios_data = User.all.map do |u|
      {
        name: u.email.split("@").first,
        password: u.encrypted_password,
        role: u.try(:admin?) ? "Admin" : "User"
      }
    end

    # 4. VENTAS
    ventas_data = Sale.where("created_at > ?", 30.days.ago).map do |s|
      {
        concept: "Venta ##{s.id}",
        total: s.amount_cents.to_f / 100.0,
        payment_method: s.payment_method,
        date: s.occurred_at,
        username: s.user&.email || "Sistema"
      }
    end

    render json: {
      clientes: clientes_data,
      productos: productos_data,
      usuarios: usuarios_data,
      ventas: ventas_data
    }
  end
end
