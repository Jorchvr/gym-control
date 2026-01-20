class ClientsController < ApplicationController
  # 🛡️ SEGURIDAD: Permitimos que el C# entre sin token.
  # 🚨 CORRECCIÓN 1: Borramos ':receive_fingerprint' de aquí porque ya no existe y daba error.
  skip_before_action :verify_authenticity_token, only: [ :check_entry, :fingerprints_data ]
  before_action :authenticate_user!, except: [ :check_entry, :fingerprints_data ]

  before_action :set_client, only: [ :show, :edit, :update, :start_registration, :fingerprint_status, :attach_last_fingerprint, :card_view ]

  # =========================================================
  # 🔌 1. HARDWARE Y SINCRONIZACIÓN C#
  # =========================================================

  # C# descarga la base de datos de huellas
  def fingerprints_data
    clients = Client.where.not(fingerprint: [ nil, "" ]).select(:id, :fingerprint, :name)
    render json: clients
  end

  # Botón para encender el lector
  def start_scanner
    Thread.new do
      puts ">>> INTENTANDO INICIAR PUENTE C#..."
      project_path = "C:\\Users\\ramoo\\Documents\\PuenteHuella"
      system("cmd.exe /C \"cd #{project_path} && dotnet run\"")
    end
    redirect_back(fallback_location: authenticated_root_path, notice: "🔌 Orden de encendido enviada.")
  end

  # EL CEREBRO: Recibe la señal del C#
  def check_entry
    # CASO A: MATCH EXITOSO (El C# encontró la huella)
    if params[:client_id].present?
      client = Client.find_by(id: params[:client_id])

      if client
        # 🚨 CORRECCIÓN 2: Asignamos un usuario por defecto.
        # Sin esto, la validación fallaba y el Home no se enteraba.
        system_user = User.first

        begin
          CheckIn.create!(
            client: client,
            occurred_at: Time.current,
            user: system_user
          )
          puts "✅ ASISTENCIA GUARDADA: #{client.name}"
        rescue => e
          puts "❌ ERROR AL GUARDAR ASISTENCIA: #{e.message}"
        end

        # (Opcional) Websockets
        ActionCable.server.broadcast("lector_huella", {
          action: "login",
          client_id: client.id,
          client_name: client.name
        })

        return render json: { status: "success", message: "Bienvenido #{client.name}" }
      end
    end

    # CASO B: HUELLA DESCONOCIDA (Para registrar)
    huella_recibida = params[:fingerprint]
    if huella_recibida.present?
      Rails.cache.write("temp_huella_manual", huella_recibida, expires_in: 10.minutes)
      ActionCable.server.broadcast("lector_huella", { action: "unknown" })
      render json: { status: "not_found", message: "Desconocida (Guardada para registro)" }, status: :not_found
    else
      render json: { status: "error", message: "Datos incompletos" }, status: :bad_request
    end
  end

  # =========================================================
  # 📡 2. VISTA EN VIVO (POLLING) - LO QUE PIDE EL HOME
  # =========================================================

  # El Home pregunta aquí cada segundo si hay alguien nuevo
  def check_latest
    # Busca un CheckIn creado hace menos de 4 segundos
    last_checkin = CheckIn.where("occurred_at > ?", 4.seconds.ago).order(created_at: :desc).first

    if last_checkin
      render json: { new_entry: true, client_id: last_checkin.client_id }
    else
      render json: { new_entry: false }
    end
  end

  # Devuelve el HTML de la tarjeta bonita
  def card_view
    render partial: "clients/card_result", locals: { client: @client }, layout: false
  end

  # =========================================================
  # 🔗 3. VINCULACIÓN MANUAL Y REGISTRO
  # =========================================================
  def attach_last_fingerprint
    huella_cache = Rails.cache.read("temp_huella_manual")
    if huella_cache.present?
      if @client.update(fingerprint: huella_cache)
        Rails.cache.delete("temp_huella_manual")
        ActionCable.server.broadcast("lector_huella", { action: "registered", client_name: @client.name })
        redirect_to @client, notice: "✅ ¡HUELLA VINCULADA CORRECTAMENTE!"
      else
        redirect_to @client, alert: "❌ Error: #{@client.errors.full_messages.join}"
      end
    else
      redirect_to @client, alert: "⚠️ No hay huella reciente en memoria."
    end
  end

  def start_registration
    redirect_to @client, notice: "Instrucciones: 1. Pon el dedo. 2. Pulsa Vincular."
  end

  def fingerprint_status
    render json: { has_fingerprint: @client.fingerprint.present? }
  end

  # =========================================================
  # 📋 4. CRUD ESTÁNDAR (Toda tu lógica original)
  # =========================================================
  def index
    @q = params[:q].to_s.strip
    @filter = params[:filter].presence || "name"
    @status = params[:status].to_s

    base_scope = ::Client.order(id: :desc)
    scope = base_scope

    if @q.present?
      if @filter == "id" && @q.to_i.to_s == @q
        scope = scope.where(id: @q.to_i)
      else
        scope = scope.where("LOWER(name) LIKE ?", "%#{@q.downcase}%")
      end
    end

    if @status == "active"
      scope = scope.where.not(next_payment_on: nil).where(::Client.arel_table[:next_payment_on].gteq(Date.current))
    end

    @clients = scope
    @active_clients_count = base_scope.where("next_payment_on >= ?", Date.current).count
  end

  def show; end
  def new; @client = ::Client.new; end
  def edit; end

  def create
    @client = ::Client.new(client_params)
    @client.user = current_user
    plan = params.dig(:client, :membership_type).to_s.presence

    unless plan.present?
      @client.errors.add(:membership_type, "debe seleccionarse")
      return render :new, status: :unprocessable_entity
    end

    amount_cents = nil
    ActiveRecord::Base.transaction do
      if @client.next_payment_on.present?
        @client.enrolled_on ||= Date.current
      else
        @client.set_enrollment_dates!(from: Date.current)
      end
      @client.save!

      sent_price_cents = parse_money_to_cents(params[:registration_price_mxn])
      default_price    = default_registration_price_cents(plan)
      amount_cents     = (sent_price_cents && sent_price_cents > 0) ? sent_price_cents : default_price

      pm = params.dig(:client, :payment_method).presence || "cash"

      Sale.create!(user: current_user, client: @client, membership_type: plan, amount_cents: amount_cents, payment_method: pm, occurred_at: Time.current)
    end
    redirect_to @client, notice: "Cliente creado."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Cliente actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = ::Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :age, :weight, :height, :membership_type, :client_number, :next_payment_on, :enrolled_on, :photo)
  end

  def default_registration_price_cents(plan)
    return 0 if plan.blank?
    Client::PRICES[plan.to_s] || 0
  end

  def parse_money_to_cents(input)
    return nil if input.blank?
    s = input.to_s.gsub(/[^\d.,-]/, "")
    s = s.delete(",") if s.include?(",") && s.include?(".")
    s = s.tr(",", ".") unless s.include?(".")
    (s.to_f * 100).round
  end
end
