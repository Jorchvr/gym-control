module ClientsHelper
  # Muestra la foto del cliente de forma robusta.
  # size: lado en px (cuadrado)
  # classes: clases extra de CSS
  def client_photo_tag(client, size: 144, classes: "")
    # Estilos inline para asegurar que el círculo se mantenga
    styles = "width: #{size}px; height: #{size}px; object-fit: cover; border-radius: 50%;"

    # 1. ¿Tiene foto en la BD?
    if client&.photo&.attached?
      begin
        # INTENTO A: Variante redimensionada (Ideal)
        return image_tag(
          client.photo.variant(resize_to_fill: [ size, size ]),
          class: "client-photo #{classes}",
          style: styles,
          alt: client.name
        )
      rescue => e
        # Si falla (ej: falta librería Vips), intentamos la original...
        begin
          # INTENTO B: Imagen original
          return image_tag(
            client.photo,
            class: "client-photo #{classes}",
            style: styles,
            alt: client.name
          )
        rescue
          # INTENTO C: Si también falla (ej: Render borró el archivo del disco),
          # No hacemos nada aquí y dejamos que el código siga hacia abajo (al Placeholder).
          puts "⚠️ Archivo de foto no encontrado en disco para Cliente ##{client.id}"
        end
      end
    end

    # 2. PLACEHOLDER (Gris): Si no hay foto o si los archivos fallaron al cargar
    content_tag(:div, "Sin foto",
      class: "client-photo ph #{classes}",
      style: "#{styles} display: flex; align-items: center; justify-content: center; background-color: #6c757d; color: white; font-size: 0.8rem;"
    )
  end
end
