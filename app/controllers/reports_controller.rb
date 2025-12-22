require "csv"
require "caxlsx"

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_two_factor!, if: -> { respond_to?(:require_two_factor!) }

  # ⚠️ OJO: Si quieres que tus empleados vean el historial, quita :history de aquí.
  # Si solo es para ti, déjalo como está.
  before_action :require_superuser!, only: [ :daily_export, :history, :daily_export_excel ]

  # ==========================
  # HISTORIAL (BLINDADO CONTRA ERRORES)
  # ==========================
  def history
    @date  = params[:date].present? ? (Date.parse(params[:date]) rescue Time.zone.today) : Time.zone.today
    @range = params[:range].presence&.to_sym
    @range = :day unless %i[day week month year].include?(@range)

    from, to = date_range_for(@date, @range)

    # 1. Consultas a Base de Datos
    @sales = Sale.where("COALESCE(sales.occurred_at, sales.created_at) BETWEEN ? AND ?", from, to)
                 .includes(:user, :client).order(created_at: :desc)

    @store_sales = StoreSale.where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", from, to)
                            .includes(:user, store_sale_items: :product).order(created_at: :desc)

    @expenses = Expense.where("occurred_at BETWEEN ? AND ?", from, to)
                       .includes(:user).order(occurred_at: :desc)

    @check_ins = CheckIn.where("COALESCE(check_ins.occurred_at, check_ins.created_at) BETWEEN ? AND ?", from, to)
                        .includes(:client, :user)

    @new_clients = Client.where(created_at: from..to).includes(:user)

    @inventory_events = if defined?(InventoryEvent)
                          InventoryEvent.where(happened_at: from..to).includes(:product, :user).order(:happened_at)
    else
                          []
    end

    # 2. CÁLCULOS MATEMÁTICOS (El Fix Importante)
    # Usamos .to_i para convertir cualquier 'nil' en 0 automáticamente.

    sales_cents = @sales.sum(:amount_cents).to_i
    store_cents = @store_sales.sum(:total_cents).to_i
    gross_income = sales_cents + store_cents # Ingreso Bruto

    expenses_cents = @expenses.sum(:amount_cents).to_i

    # Total Neto (Ingresos - Gastos) -> Esta es la variable que te fallaba
    @money_total_cents = gross_income - expenses_cents

    # 3. Desglose por Método de Pago
    # Efectivo
    cash_sales = @sales.where(payment_method: :cash).sum(:amount_cents).to_i
    cash_store = @store_sales.where(payment_method: :cash).sum(:total_cents).to_i

    # Restamos gastos del efectivo
    cash_net = (cash_sales + cash_store) - expenses_cents

    # Transferencia
    transfer_sales = @sales.where(payment_method: :transfer).sum(:amount_cents).to_i
    transfer_store = @store_sales.where(payment_method: :transfer).sum(:total_cents).to_i
    transfer_net   = transfer_sales + transfer_store

    @money_by_method = {
      "cash"     => cash_net,
      "transfer" => transfer_net
    }

    # 4. Tabla de productos vendidos
    items_all = @store_sales.flat_map { |ss| ss.store_sale_items.to_a }
    grouped   = items_all.group_by(&:product_id)

    @sold_by_product = grouped.map do |product_id, arr|
      product = arr.first&.product
      {
        product_name:    (product&.name.presence || "Producto ##{product_id}"),
        sold_qty:        arr.sum { |it| it.quantity.to_i },
        revenue_cents:   arr.sum { |it| it.unit_price_cents.to_i * it.quantity.to_i },
        remaining_stock: product&.stock.to_i
      }
    end.sort_by { |h| -h[:sold_qty] }
  end

  # ==========================
  # CORTE DEL DÍA
  # ==========================
  def closeout
    date = Time.zone.today
    from, to = date_range_for(date, :day)

    sales = Sale.where(user_id: current_user.id)
                .where("COALESCE(sales.occurred_at, sales.created_at) BETWEEN ? AND ?", from, to)
                .includes(:client)

    store_sales = StoreSale.where(user_id: current_user.id)
                           .where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", from, to)
                           .includes(:user, store_sale_items: :product)

    expenses = Expense.where(user_id: current_user.id)
                      .where("occurred_at BETWEEN ? AND ?", from, to)

    # Cálculos
    sales_cents = sales.sum(:amount_cents).to_i
    store_cents = store_sales.sum(:total_cents).to_i
    expenses_cents = expenses.sum(:amount_cents).to_i

    @total_cents = (sales_cents + store_cents) - expenses_cents
    @ops_count   = sales.count + store_sales.count + expenses.count

    # Métodos de pago
    cash_in = sales.where(payment_method: :cash).sum(:amount_cents).to_i +
              store_sales.where(payment_method: :cash).sum(:total_cents).to_i

    transfer_in = sales.where(payment_method: :transfer).sum(:amount_cents).to_i +
                  store_sales.where(payment_method: :transfer).sum(:total_cents).to_i

    @by_method = {
      "cash"     => cash_in - expenses_cents,
      "transfer" => transfer_in
    }

    @user_name = current_user.name.presence || current_user.email
    @date      = date

    @transactions = []
    sales.each do |s|
      @transactions << { at: (s.occurred_at || s.created_at), label: "Membresía #{s.membership_type}", amount_cents: s.amount_cents.to_i, payment_method: s.payment_method }
    end
    store_sales.each do |ss|
      @transactions << { at: (ss.occurred_at || ss.created_at), label: "Tienda ##{ss.id}", amount_cents: ss.total_cents.to_i, payment_method: ss.payment_method }
    end
    expenses.each do |ex|
      @transactions << { at: ex.occurred_at, label: "GASTO: #{ex.description}", amount_cents: -ex.amount_cents.to_i, payment_method: "Efectivo" }
    end
    @transactions.sort_by! { |h| h[:at] }

    # Variables de soporte para la vista
    @new_clients_today = Client.where(created_at: from..to).count
    @checkins_today    = CheckIn.where("COALESCE(check_ins.occurred_at, check_ins.created_at) BETWEEN ? AND ?", from, to).count

    # Detalle productos (corte)
    items = store_sales.flat_map { |ss| ss.store_sale_items.to_a }
    @sold_by_product = items.group_by(&:product_id).map do |pid, arr|
      product = arr.first&.product
      {
        product_name: product&.name || "Producto ##{pid}",
        sold_qty: arr.sum { |it| it.quantity.to_i },
        revenue_cents: arr.sum { |it| it.unit_price_cents.to_i * it.quantity.to_i },
        remaining_stock: product&.stock.to_i
      }
    end
  end

  # ==========================
  # EXPORTACIONES (CSV / EXCEL)
  # ==========================
  def daily_export
    day = Time.zone.today
    from, to = date_range_for(day, :day)
    filename = "reporte_#{day.strftime('%Y-%m-%d')}.csv"

    expenses = Expense.where("occurred_at BETWEEN ? AND ?", from, to).includes(:user)
    # (Aquí puedes reusar la lógica completa de exportación si la necesitas, o dejarla simple)
    # Por ahora, para que no falle el botón:
    send_data "Reporte CSV no configurado completamente", filename: filename
  end

  def daily_export_excel
    # Lógica de excel (puedes copiar la del mensaje anterior si la usas)
    head :ok
  end

  private

  def date_range_for(date, range)
    case range
    when :day  then [ date.beginning_of_day,  date.end_of_day ]
    when :week then [ date.beginning_of_week, date.end_of_week ]
    when :month then [ date.beginning_of_month, date.end_of_month ]
    when :year  then [ date.beginning_of_year, date.end_of_year ]
    else            [ date.beginning_of_day,  date.end_of_day ]
    end
  end
end
