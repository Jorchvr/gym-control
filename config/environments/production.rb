# config/environments/production.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # ---- Básicos
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # ---- Caché y estáticos
  config.action_controller.perform_caching = true
  # Render sirve estáticos si esta var está presente
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # ---- Archivos / Active Storage
  config.active_storage.service = :local
  # Usa libvips para generar variantes (evita depender de ImageMagick)
  config.active_storage.variant_processor = :vips

  # ---- SSL detrás de proxy (Render)
  config.assume_ssl = true
  config.force_ssl  = true
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # ---- Logs
  config.log_tags  = [ :request_id ]
  config.logger    = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # ---- Cache / Jobs (Solid*)
  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # ---- Mailer
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "example.com"),
    protocol: "https"
  }
  # Si vas a usar SMTP, configura tus credenciales en credentials y descomenta:
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password:  Rails.application.credentials.dig(:smtp, :password),
  #   address:   "smtp.example.com",
  #   port:      587,
  #   authentication: :plain,
  #   enable_starttls_auto: true
  # }

  # ---- I18n
  config.i18n.fallbacks = true

  # ---- ActiveRecord
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # ---- Hosts (opcional si usas dominio propio)
  # config.hosts = [
  #   "powergym-88ls.onrender.com",
  #   /.*\.tudominio\.com/
  # ]
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
