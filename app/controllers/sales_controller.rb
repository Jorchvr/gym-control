class SalesController < ApplicationController
  before_action :authenticate_user!

  # GET /sales
  def index
    @date =
      if params[:date].present?
        Date.parse(params[:date]) rescue Time.zone.today
      else
        Time.zone.today
      end

    from = @date.beginning_of_day
    to   = @date.end_of_day

    user_scope_id = current_user.id

    if superuser?
      if params[:all].present?
        user_scope_id = nil
      elsif params[:user_id].present?
        user_scope_id = params[:user_id].to_i
      end
    end

    sales_scope =
      if defined?(Sale)
        Sale.where("COALESCE(sales.occurred_at, sales.created_at) BETWEEN ? AND ?", from, to)
      else
        Sale.none
      end

    store_sales_scope =
      if defined?(StoreSale)
        StoreSale.where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", from, to)
      else
        StoreSale.none
      end

    if user_scope_id
      sales_scope       = sales_scope.where(user_id: user_scope_id)
      store_sales_scope = store_sales_scope.where(user_id: user_scope_id)
    end

    @transactions = []

    sales_scope.includes(:user, :client).find_each do |s|
      @transactions << {
        kind: :membership,
        id: s.id,
        at: (s.occurred_at || s.created_at),
        user: s.user,
        client: s.client,
        amount_cents: s.amount_cents.to_i,
        payment_method: s.payment_method,
        label: "Membresía #{s.membership_type}"
      }
    end

    store_sales_scope.includes(:user).find_each do |ss|
      @transactions << {
        kind: :store,
        id: ss.id,
        at: (ss.occurred_at || ss.created_at),
        user: ss.user,
        client: nil,
        amount_cents: ss.total_cents.to_i,
        payment_method: ss.payment_method,
        label: "Tienda (##{ss.id})"
      }
    end

    @transactions.sort_by! { |h| h[:at] }
    @count         = @transactions.size
    @total_cents   = @transactions.sum { |h| h[:amount_cents] }
    @selected_user = user_scope_id ? User.find_by(id: user_scope_id) : nil
  end

  def show
    # ...
  end

  # =====================================================
  # SECCIÓN PROTEGIDA: AJUSTES / VENTAS NEGATIVAS (SOLO TIENDA ONLINE)
  # =====================================================

  def adjustments
    @date = Time.zone.today
    @from = @date.beginning_of_day
    @to   = @date.end_of_day

    unless session[:store_adjustments_unlocked]
      @needs_unlock = true
      return
    end

    scope = StoreSale.where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", @from, @to)
    scope = scope.where(user_id: current_user.id) unless superuser?

    store_sales = scope.includes(:user, store_sale_items: :product).to_a

    @store_sales = store_sales.select do |ss|
      ss.store_sale_items.any? do |it|
        prod = it.product
        prod.present? && prod.name != "Servicio Griselle"
      end
    end
  end

  # POST /sales/unlock_adjustments
  # Código secreto: 010101
  def unlock_adjustments
    code     = params[:security_code].to_s.strip
    expected = "010101"

    ok =
      code.present? &&
      expected.present? &&
      code.length == expected.length &&
      ActiveSupport::SecurityUtils.secure_compare(code, expected)

    if ok
      session[:store_adjustments_unlocked] = true
      redirect_to adjustments_sales_path, notice: "Sección de ajustes de tienda desbloqueada."
    else
      session[:store_adjustments_unlocked] = false
      redirect_to adjustments_sales_path, alert: "Código de seguridad incorrecto."
    end
  end

  # POST /sales/reverse_transaction
  def reverse_transaction
    unless session[:store_adjustments_unlocked]
      redirect_to adjustments_sales_path, alert: "Debes ingresar el código de seguridad."
      return
    end

    ss_id    = params[:store_sale_id].to_i
    original = StoreSale.includes(store_sale_items: :product).find_by(id: ss_id)

    unless original
      redirect_to adjustments_sales_path, alert: "Venta de tienda no encontrada."
      return
    end

    if original.total_cents.to_i <= 0
      redirect_to adjustments_sales_path, alert: "Esta venta ya es un ajuste o negativa y no se puede revertir."
      return
    end

    if !superuser? && original.user_id != current_user.id
      redirect_to adjustments_sales_path, alert: "No puedes ajustar ventas de otros usuarios."
      return
    end

    reason = params[:reason].to_s.strip

    StoreSale.transaction do
      attrs = {
        user:           current_user,
        payment_method: original.payment_method,
        total_cents:    -original.total_cents.to_i,
        occurred_at:    Time.current
      }

      base_reason = reason.presence || "ajuste de tienda"
      if StoreSale.column_names.include?("description")
        attrs[:description] = "VENTA NEGATIVA (DEVOLUCIÓN) de venta ##{original.id} - #{base_reason}"
      elsif StoreSale.column_names.include?("note")
        attrs[:note] = "VENTA NEGATIVA (DEVOLUCIÓN) de venta ##{original.id} - #{base_reason}"
      end

      if StoreSale.column_names.include?("metadata")
        attrs[:metadata] = { reversal_of_id: original.id, reason: reason }
      end

      reversal = StoreSale.new(attrs)
      reversal.save!(validate: false)

      original.store_sale_items.find_each do |item|
        base_desc =
          if item.respond_to?(:description) && item.description.present?
            item.description
          elsif item.product
            "#{item.product.name} x#{item.quantity}"
          else
            "Item #{item.id}"
          end

        reversal_item = reversal.store_sale_items.build(
          product_id:        item.product_id,
          quantity:          item.quantity,
          unit_price_cents: -item.unit_price_cents.to_i
        )

        if reversal_item.respond_to?(:description)
          reversal_item.description = "DEVOLUCIÓN - #{base_desc}"
        end

        reversal_item.save!(validate: false)

        if (product = item.product)
          product.update!(stock: product.stock.to_i + item.quantity.to_i)
        end
      end
    end

    redirect_to adjustments_sales_path, notice: "Venta negativa creada (DEVOLUCIÓN) y stock regresado para la venta de tienda ##{original.id}."
  rescue => e
    redirect_to adjustments_sales_path, alert: "No se pudo crear la venta negativa: #{e.message}"
  end



  # =====================================================================
  # ✅ NUEVO MÉTODO: CORTE DEL DÍA (SIN MODIFICAR NADA DEL CONTROLADOR)
  # =====================================================================
  def corte
    @date = Time.zone.today
    from  = @date.beginning_of_day
    to    = @date.end_of_day

    user = current_user
    @user_name = user.name rescue user.email

    # VENTAS DEL DÍA
    sales = Sale.where("COALESCE(occurred_at, created_at) BETWEEN ? AND ?", from, to)
    store_sales = StoreSale.where("COALESCE(occurred_at, created_at) BETWEEN ? AND ?", from, to)

    unless superuser?
      sales       = sales.where(user_id: user.id)
      store_sales = store_sales.where(user_id: user.id)
    end

    @ops_count = sales.count + store_sales.count

    @member_cents      = sales.sum(:amount_cents).to_i
    @store_cents       = store_sales.sum(:total_cents).to_i
    @adjustments_cents = store_sales.where("total_cents < 0").sum(:total_cents).to_i

    @total_cents = @member_cents + @store_cents + @adjustments_cents

    # PAGOS
    @by_method = { "cash" => 0, "transfer" => 0 }

    sales.each do |s|
      pm = s.payment_method.to_s
      @by_method[pm] += s.amount_cents.to_i if @by_method.key?(pm)
    end

    store_sales.each do |ss|
      pm = ss.payment_method.to_s
      @by_method[pm] += ss.total_cents.to_i if @by_method.key?(pm)
    end

    # CHECKINS Y NUEVOS CLIENTES
    @checkins_today = Checkin.where(created_at: from..to).count
    @new_clients_today = Client.where(created_at: from..to).count
  end


  private

  def superuser?
    current_user.respond_to?(:superuser?) ? current_user.superuser? : false
  end
end
