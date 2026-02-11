require "base64"

class Api::V1::SyncController < ApplicationController
  # Saltamos la verificación para que C# pueda entrar sin problemas
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    begin
      # 1. PROCESAR CLIENTES
      clientes_data = Client.all.map do |c|
        huella_base64 = nil

        if c.respond_to?(:fingerprint) && c.fingerprint.present?
          raw_data = c.fingerprint
          # Limpieza binaria para Postgres (\x)
          if raw_data.is_a?(String) && raw_data.start_with?("\\x")
            raw_data = [ raw_data[2..-1] ].pack("H*")
          end
          huella_base64 = Base64.strict_encode64(raw_data)
        end

        {
          id: c.id,
          name: c.try(:name) || c.try(:full_name) || "Sin Nombre",
          fingerprint_template: huella_base64,
          # Usamos try para evitar errores si la columna se llama distinto
          expiration_date: c.try(:next_payment_on) || c.try(:expiration_date),
          registration_date: c.created_at
        }
      end

      # 2. PROCESAR PRODUCTOS
      productos_data = Product.all.map do |p|
        {
          id: p.id,
          name: p.name,
          # Manejamos si usas centavos o moneda normal
          price: p.try(:price_cents) ? (p.price_cents.to_f / 100.0) : p.try(:price).to_f,
          stock: p.try(:stock) || 0
        }
      end

      # 3. ENVIAR RESPUESTA EXITOSA
      render json: {
        clientes: clientes_data,
        productos: productos_data,
        status: "success"
      }

    rescue => e
      # Si algo falla, el servidor te enviará el mensaje de error en JSON
      # en lugar de darte el Error 500 genérico.
      render json: {
        status: "error",
        message: e.message,
        location: e.backtrace.first
      }, status: 500
    end
  end
end
