require "base64"

class Api::V1::SyncController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def full_sync
    # BUSCAMOS LAS HUELLAS "A LA FUERZA"
    clientes_data = Client.all.map do |c|
      # 1. Intentamos encontrar la huella en cualquier columna probable
      raw = c.try(:fingerprint) || c.try(:huella) || c.try(:fingerprint_template) || c.try(:template)

      huella_final = nil

      if raw.present?
        # 2. LIMPIEZA PROFUNDA DE FORMATO POSTGRES
        # Si Postgres nos da el formato "\x504B...", lo convertimos a binario real
        if raw.is_a?(String) && raw.start_with?("\\x")
          # Quitamos el \x y empaquetamos los hexas a bytes
          raw = [ raw[2..-1] ].pack("H*")
        end

        # 3. Convertimos a Base64 Estricto (Sin saltos de línea)
        huella_final = Base64.strict_encode64(raw)
      end

      {
        id: c.id,
        name: c.try(:name) || c.try(:full_name) || "Sin Nombre",
        # ESTE ES EL CAMPO CLAVE QUE RECIBIRÁ C#:
        fingerprint_template: huella_final,
        expiration_date: c.try(:next_payment_on) || c.try(:expiration_date),
        registration_date: c.created_at,
        photo_path: c.respond_to?(:photo) && c.photo.attached? ? url_for(c.photo) : nil
      }
    end

    render json: {
      clientes: clientes_data,
      # Enviamos productos también para que no falle la tienda
      productos: Product.all.map { |p| { id: p.id, name: p.name, price: p.try(:price_cents).to_f/100, stock: p.try(:stock) || 0 } },
      status: "success"
    }
  rescue => e
    # Si falla, te dirá exactamente por qué en el JSON
    render json: { status: "error", message: e.message, backtrace: e.backtrace.first }, status: 500
  end
end
