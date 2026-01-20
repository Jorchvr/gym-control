# config/initializers/hardware_start.rb

# Este código se ejecuta automáticamente cuando escribes 'rails s'
if defined?(Rails::Server)
  Thread.new do
    # 1. Esperamos 3 segundos para asegurar que Rails ya arrancó bien
    sleep 3

    puts "\n" + "="*50
    puts "🔌 INICIANDO PUENTE DE HUELLA AUTOMÁTICAMENTE..."
    puts "=================================================="

    # 2. Definimos la ruta de tu programa C# (La saqué de tus logs)
    # NOTA: En Windows las barras invertidas deben ser dobles \\
    path = "C:\\Users\\ramoo\\Documents\\PuenteHuella"

    # 3. Ejecutamos el programa.
    # El comando cmd.exe /C ejecuta y mantiene vivo el proceso dentro de esta terminal.
    system("cmd.exe /C \"cd #{path} && dotnet run\"")
  end
end
