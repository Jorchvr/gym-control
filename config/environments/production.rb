require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Code reloading prohibido en producción para velocidad
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # =========================================================
  # 🛠️ SOLUCIÓN HUELLA DIGITAL (MEMORIA RAM)
  # =========================================================
  # Usamos :memory_store para que Rails guarde la huella y las sesiones
  # en la RAM del servidor Render. Esto soluciona el "No hay huella reciente".
  config.cache_store = :memory_store, { size: 64.megabytes }

  # Storage (Imágenes)
  # NOTA: En Render gratuito/básico, las imágenes se borran al hacer deploy con :local.
  # Para huellas está bien, pero para fotos de perfil necesitarías AWS S3 o Cloudinary a futuro.
  config.active_storage.service = :local

  # Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = {
    host: "powergym-88ls.onrender.com",
    protocol: "https"
  }

  # Optimizaciones de Assets y SSL
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.assets.compile = false # Render precompila los assets en el build
  config.assume_ssl = true
  config.force_ssl = true

  # Logs limpios
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = "info"
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # Jobs y Cache
  config.active_job.queue_adapter = :async
  config.action_controller.perform_caching = true

  # I18n / DB
  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
end
