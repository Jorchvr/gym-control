class FingerprintChannel < ApplicationCable::Channel
  def subscribed
    # Creamos una sala de chat llamada "lector_huella"
    stream_from "lector_huella"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
