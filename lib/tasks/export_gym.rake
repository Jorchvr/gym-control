# Ejemplo para ejecutar en rails console
File.open("clientes_huellas.json", "w") do |f|
  data = Client.all.map do |client|
    {
      nombre: client.name,
      email: client.email,
      huella_binaria: Base64.encode64(client.fingerprint_data) # Convierte el binario a texto
    }
  end
  f.write(JSON.pretty_generate(data))
end