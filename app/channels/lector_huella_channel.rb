class LectorHuellaChannel < ApplicationCable::Channel
  def subscribed
    # Esto es vital: crea la frecuencia de radio "lector_huella"
    stream_from "lector_huella"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
