module Api
  module V1
    class UsersController < ApplicationController
      def sync_users
        # 1. Recuperamos TODOS los clientes (evitamos filtrar por columna 'fingerprint'
        # en la consulta SQL por si la columna no existe o se llama diferente,
        # para que no explote aquí mismo).
        clients_db = Client.all

        data = []

        clients_db.each do |c|
          # 2. INTENTAMOS LEER LA HUELLA DE FORMA SEGURA
          # Probamos todos los nombres posibles. Si no existe ninguno, devuelve nil.
          huella = c.try(:fingerprint) || c.try(:fingerprint_template) || c.try(:huella)

          # Si no tiene huella, saltamos al siguiente cliente (no lo enviamos)
          next if huella.blank?

          # 3. CONSTRUIMOS EL OBJETO CON 'TRY' PARA TODO
          data << {
            id: c.id,
            # Busca name, o nombre, o first_name, o string vacío
            name: c.try(:name) || c.try(:nombre) || c.try(:first_name) || "Sin Nombre",

            fingerprint_template: huella,

            # Si created_at falla, usa la hora actual
            registration_date: c.try(:created_at) || Time.now,

            # Busca scanning_until, expiration_date, o suma 30 días
            expiration_date: c.try(:scanning_until) || c.try(:expiration_date) || (Time.now + 30.days),

            membership_type: "Estándar"
          }
        end

        render json: data
      end
    end
  end
end
