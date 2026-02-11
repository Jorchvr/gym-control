require "base64"

class Api::V1::SyncController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    # 1. Buscamos solo clientes que tengan huella para no perder tiempo
    clientes_con_huella = Client.where("fingerprint IS NOT NULL")

    clientes_data = clientes_con_huella.map do |c|
      huella_limpia = nil

      # --- EL SECRETO DE LOS 2176 BYTES ---
      if c.fingerprint.present?
        raw = c.fingerprint

        # Si Postgres nos da el formato de texto "\x..." (Hexadecimal)
        if raw.is_a?(String) && raw.start_with?("\\x")
          # Quitamos la "x" y convertimos el texto a archivo real
          # Esto bajará el peso de 2176 a aprox 1088 bytes (lo correcto)
          raw = [ raw[2..-1] ].pack("H*")
        end

        # Convertimos a Base64 para enviarlo a C#
        huella_limpia = Base64.strict_encode64(raw)
      end
      # ------------------------------------

      {
        id: c.id,
        name: c.name || "Cliente #{c.id}",
        fingerprint_template: huella_limpia, # C# recibirá esto
        expiration_date: c.next_payment_on,
        registration_date: c.created_at,
        # Si tienes ActiveStorage configurado, usa esto, sino envía null
        photo_path: nil
      }
    end

    # Agregamos los productos para que la tienda funcione
    productos_data = Product.all.map do |p|
      {
        id: p.id,
        name: p.name,
        price: p.respond_to?(:price_cents) ? p.price_cents.to_f/100 : 0,
        stock: p.respond_to?(:stock) ? p.stock : 0
      }
    end

    render json: {
      clientes: clientes_data,
      productos: productos_data,
      status: "success"
    }
  rescue => e
    render json: { status: "error", message: e.message }, status: 500
  end
end
