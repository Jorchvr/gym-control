require "base64"

class Api::V1::SyncController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    # 1. PROCESAR CLIENTES Y LIMPIAR HUELLAS
    clientes_data = Client.all.map do |c|
      huella_base64 = nil

      if c.fingerprint.present?
        raw_data = c.fingerprint

        # Si Postgres entrega un String Hexadecimal (ej: "\x504b...")
        if raw_data.is_a?(String) && raw_data.start_with?("\\x")
          # Quitamos el "\x" y convertimos el texto hex a binario puro
          raw_data = [ raw_data[2..-1] ].pack("H*")
        end

        # Convertimos el binario limpio a Base64 estricto
        huella_base64 = Base64.strict_encode64(raw_data)
      end

      {
        id: c.id,
        name: c.name,
        fingerprint_template: huella_base64,
        expiration_date: c.next_payment_on,
        registration_date: c.created_at,
        photo_path: c.photo.attached? ? url_for(c.photo) : nil
      }
    end

    # 2. PROCESAR OTROS DATOS
    productos_data = Product.all.map { |p| { id: p.id, name: p.name, price: p.price_cents.to_f/100, stock: p.stock } }
    usuarios_data = User.all.map { |u| { name: u.email, role: u.admin? ? "Admin" : "User" } }

    # 3. ENVIAR TODO EL PAQUETE
    render json: {
      clientes: clientes_data,
      productos: productos_data,
      usuarios: usuarios_data
    }
  end
end
