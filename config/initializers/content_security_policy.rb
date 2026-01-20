# config/initializers/content_security_policy.rb

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none

    # 👇 ESTO ES LO QUE ARREGLA EL BLOQUEO:
    # 1. Permitimos estilos y scripts escritos en el HTML (:unsafe_inline)
    policy.script_src  :self, :https, :unsafe_inline
    policy.style_src   :self, :https, :unsafe_inline

    # 2. Permitimos conexiones al servidor local (para que el fetch funcione)
    policy.connect_src :self, :https, "http://localhost:3000", "ws://localhost:3000", "http://127.0.0.1:3000", "ws://127.0.0.1:3000"
  end

  # 🚨 VITAL: Desactivar el generador de nonces para que no choque con tu script
  config.content_security_policy_nonce_generator = nil
end
