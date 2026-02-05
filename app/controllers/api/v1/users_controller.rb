module Api
  module V1
    class UsersController < ApplicationController
      def sync_users
        # Traemos TODOS los clientes
        clients_db = Client.all

        data = []

        clients_db.each do |c|
          # Intentamos leer la huella (si no tiene, será nil)
          huella = c.try(:fingerprint) || c.try(:fingerprint_template) || c.try(:huella)

          # --- CAMBIO IMPORTANTE: YA NO FILTRAMOS LOS QUE NO TIENEN HUELLA ---
          # Antes teníamos: next if huella.blank?  <-- ESTO LO QUITAMOS

          data << {
            id: c.id,
            name: c.try(:name) || c.try(:nombre) || c.try(:first_name) || "Sin Nombre",
            fingerprint_template: huella, # Puede ir vacío o nil
            registration_date: c.try(:created_at) || Time.now,
            expiration_date: c.try(:scanning_until) || c.try(:expiration_date) || (Time.now + 30.days),
            membership_type: "Estándar"
          }
        end

        render json: data
      end
    end
  end
end
