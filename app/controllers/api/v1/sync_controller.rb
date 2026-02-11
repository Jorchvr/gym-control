require "base64"

class Api::V1::SyncController < ApplicationController
  # ESTAS DOS LÍNEAS ELIMINAN EL ERROR 422
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    clientes_data = []

    # Procesamos uno por uno para que si uno falla, no detenga a los demás
    Client.find_each do |c|
      begin
        huella_limpia = nil

        if c.fingerprint.present?
          raw = c.fingerprint

          # DETECCIÓN Y CORRECCIÓN DE FORMATO POSTGRES (HEXADECIMAL)
          # Si empieza con "\x", es texto hexadecimal que debe ser binario
          if raw.is_a?(String) && raw.start_with?("\\x")
            # Esto convierte los 2176 bytes de texto en 1088 bytes de archivo real
            raw = [ raw[2..-1] ].pack("H*")
          end

          # Convertimos a Base64 para que viaje seguro a C#
          huella_limpia = Base64.strict_encode64(raw)
        end

        clientes_data << {
          id: c.id,
          name: c.try(:name) || c.try(:full_name) || "Cliente #{c.id}",
          fingerprint_template: huella_limpia,
          expiration_date: c.try(:next_payment_on) || c.try(:expiration_date),
          registration_date: c.created_at,
          photo_path: nil
        }
      rescue => e
        # Si un cliente falla, lo imprimimos en el log de Render pero NO rompemos la carga
        puts "Error procesando cliente #{c.id}: #{e.message}"
        next
      end
    end

    # Productos
    productos_data = Product.all.map do |p|
      {
        id: p.id,
        name: p.name,
        price: p.respond_to?(:price_cents) ? (p.price_cents.to_f / 100.0) : 0.0,
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
