# config/environments/production.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Code reloading prohibido en producción para velocidad
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # =========================================================
  # 🛠️ SOLUCIÓN ERROR 500 (ArgumentError: No unique index...)
  # =========================================================
  # Usamos la memoria RAM para la caché en lugar de la Base de Datos.
  # Esto evita el error al guardar la huella temporalmente.
  config.cache_store = :memory_store, { size: 64.megabytes }

  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Storage (Imágenes)
  config.active_storage.service = :local

  # SSL / proxy
  config.assume_ssl = true
  config.force_ssl = true

  # Logs
  config.log_tags  = [ :request_id ]
  config.logger    = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # 🔸 Jobs: usar :async para evitar configurar Redis/SolidQueue ahora
  config.active_job.queue_adapter = :async

  # Mailer
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "powergym-88ls.onrender.com"),
    protocol: "https"
  }

  # I18n / ActiveRecord
  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
