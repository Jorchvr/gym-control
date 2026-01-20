class FingerprintsController < ApplicationController
  # Saltamos la verificación de token porque esto viene de tu hardware local
  skip_before_action :verify_authenticity_token

  def trigger
    fingerprint_data = params[:huella_code] # El código que manda tu lector

    # LÓGICA: Buscamos al cliente
    client = Client.find_by(fingerprint: fingerprint_data)

    if client
      # Si existe, le avisamos al navegador que se mueva
      ActionCable.server.broadcast("lector_huella", {
        status: "success",
        action: "login",
        client_id: client.id
      })
      render json: { message: "Cliente encontrado" }
    else
      # Si no existe, avisamos error
      ActionCable.server.broadcast("lector_huella", { status: "error" })
      render json: { message: "No encontrado" }, status: 404
    end
  end
end
