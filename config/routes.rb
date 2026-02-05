Rails.application.routes.draw do
  # 🔌 1. HABILITAR WEBSOCKETS
  mount ActionCable.server => "/cable"

  # CONFIGURACIÓN DE USUARIOS (Devise - Admins/Staff)
  devise_for :users
  devise_scope :user do
    unauthenticated { root to: "devise/sessions#new" }
    authenticated   { root to: "dashboard#home", as: :authenticated_root }
  end

  # =========================================================
  # 👥 CLIENTES Y HUELLA (El corazón del sistema)
  # =========================================================
  resources :clients do
    member do
      post :start_registration
      post :attach_last_fingerprint
      get  :fingerprint_status
      get  :card_view   # <--- VITAL: Para pintar la tarjeta vía Turbo o AJAX
    end

    # Acciones generales
    collection do
      # 🚨 RUTA CRÍTICA ACTUALIZADA:
      # Ahora acepta POST (App C#) y GET (Pruebas manuales)
      post :check_entry
      get  :check_entry

      # 📥 C# descarga huellas aquí (Ruta antigua, la mantenemos por si acaso)
      get :fingerprints_data

      # Botón "Encender Lector"
      post :start_scanner

      # 📡 RUTA DE RASTREO: El Home pregunta aquí si hay alguien nuevo (Polling)
      get :check_latest

      # (Compatibilidad)
      get :last_entry
    end
  end

  # =========================================================
  # 💰 VENTAS Y CAJA
  # =========================================================
  resources :sales, only: [ :index, :show ] do
    collection do
      get  :corte
      get  :adjustments
      post :unlock_adjustments
      post :reverse_transaction
    end
  end

  resources :products
  resources :expenses, only: [ :new, :create, :destroy ]

  # =========================================================
  # 🛒 CARRITO DE COMPRAS
  # =========================================================
  resource :cart, only: [ :show ], controller: :cart do
    post :add
    post :increment
    post :decrement
    post :remove
    post :checkout
  end

  # Carrito secundario (Griselle)
  resource :griselle_cart, only: [ :show ], controller: :griselle_cart do
    post :add
    post :increment
    post :decrement
    post :remove
    post :checkout
  end

  # =========================================================
  # 📊 REPORTES Y MEMBRESIAS
  # =========================================================
  get "reports/daily_export",        to: "reports#daily_export",        as: :reports_daily_export
  get "reports/daily_export_excel",  to: "reports#daily_export_excel",  as: :reports_daily_export_excel
  get "history",                     to: "reports#history",             as: :history
  get "closeout",                    to: "reports#closeout",            as: :closeout

  get  "memberships",          to: "memberships#new",      as: :memberships
  post "memberships/checkout", to: "memberships#checkout", as: :memberships_checkout

  # =========================================================
  # 🔌 API PARA ESCRITORIO (Sincronización C#)
  # =========================================================
  # Esta es la parte nueva que acabamos de agregar:
  namespace :api do
    namespace :v1 do
      # Ruta: http://localhost:3000/api/v1/sync_users
      get "sync_users", to: "users#sync_users"
    end
  end

  # ADMIN
  namespace :admin do
    resources :users, only: [ :index, :new, :create ]
  end
end
