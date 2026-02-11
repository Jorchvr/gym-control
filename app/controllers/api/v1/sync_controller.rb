class Api::V1::SyncController < ApplicationController
  # IMPORTANTE: Esto permite que C# entre sin errores de seguridad
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def full_sync
    clientes_data = []

    Client.find_each do |c|
      begin
        # ESTRATEGIA: Enviamos el dato CRUDO.
        # Si es "\x504B...", enviamos exactamente eso.
        huella_raw = c.fingerprint

        clientes_data << {
          id: c.id,
          name: c.try(:name) || "Sin Nombre",
          # Enviamos el string directo, C# se encargará de entenderlo
          fingerprint_template: huella_raw,
          expiration_date: c.try(:next_payment_on),
          registration_date: c.created_at
        }
      rescue => e
        next # Si uno falla, seguimos con el otro
      end
    end

    render json: {
      clientes: clientes_data,
      productos: Product.all.map { |p| { id: p.id, name: p.name, price: p.try(:price_cents).to_f/100, stock: p.try(:stock) || 0 } },
      status: "success"
    }
  end
end
