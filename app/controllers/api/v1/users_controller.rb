# app/controllers/api/v1/users_controller.rb

module Api
  module V1
    class UsersController < ApplicationController
      # skip_before_action :verify_authenticity_token

      def sync_users
        # 1. Buscamos en CLIENTES (Client), no en usuarios del sistema (User)
        # 2. Guardamos el resultado en la variable 'clients'
        clients = Client.where.not(fingerprint_template: nil).select(:id, :name, :fingerprint_template)

        # 3. Renderizamos esa misma variable 'clients'
        render json: clients
      end
    end
  end
end
