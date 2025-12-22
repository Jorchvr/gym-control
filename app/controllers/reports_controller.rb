require "csv"
require "caxlsx"

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_two_factor!, if: -> { respond_to?(:require_two_factor!) }
  # Solo superusuario puede ver historial y exportar; el corte lo ve cualquiera
  before_action :require_superuser!, only: [ :daily_export, :history, :daily_export_excel ]

  # ==========================
  # CORTE DEL DÍA (ticket para el usuario actual)
  # ==========================
  def closeout
    date = Time.zone.today
    from, to = date_range_for(date, :day)

    # Ventas de Membresías
    sales = Sale.where(user_id: current_user.id)
                .where("COALESCE(sales.occurred_at, sales.created_at) BETWEEN ? AND ?", from, to)
                .includes(:client)

    # Ventas de Tienda
    store_sales = StoreSale.where(user_id: current_user.id)
                           .where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", from, to)
                           .includes(:user, store_sale_items: :product)

    # Gastos / Servicios (NUEVO)
    expenses = Expense.where(user_id: current_user.id)
                      .where("occurred_at BETWEEN ? AND ?", from, to)

    # ==== Totales ====
    pos_member_cents = sales.where("amount_cents >= 0").sum(:amount_cents).to_i
    pos_store_cents  = store_sales.where("total_cents >= 0").sum(:total_cents).to_i

    neg_member_cents = sales.where("amount_cents < 0").sum(:amount_cents).to_i
    neg_store_cents  = store_sales.where("total_cents < 0").sum(:total_cents).to_i

    expenses_cents   = expenses.sum(:amount_cents).to_i

    @member_cents      = pos_member_cents
    @store_cents       = pos_store_cents
    @adjustments_cents = neg_member_cents + neg_store_cents
    @expenses_cents    = expenses_cents # Variable para la vista si la necesitas

    @ops_count         = sales.count + store_sales.count + expenses.count

    # TOTAL FINAL: (Ventas + Ajustes) - Gastos
    @total_cents       = (@member_cents + @store_cents + @adjustments_cents) - @expenses_cents

    # Métodos de pago
    cash_income = sales.where(payment_method: :cash).sum(:amount_cents).to_i +
                  store_sales.where(payment_method: :cash).sum(:total_cents).to_i

    transfer_income = sales.where(payment_method: :transfer).sum(:amount_cents).to_i +
                      store_sales.where(payment_method: :transfer).sum(:total_cents).to_i

    # Asumimos que los servicios se pagan en efectivo, así que restamos de la caja "cash"
    cash_total = cash_income - @expenses_cents

    @by_method = {
      "cash"     => cash_total,
      "transfer" => transfer_income
    }

    @user_name         = current_user.name.presence || current_user.email
    @date              = date
    @new_clients_today = Client.where(created_at: from..to).count
    @checkins_today    = CheckIn.where("COALESCE(check_ins.occurred_at, check_ins.created_at) BETWEEN ? AND ?", from, to).count

    # Movimientos del turno (para la tabla interna del ticket)
    @transactions = []

    sales.each do |s|
      @transactions << {
        at:             (s.occurred_at || s.created_at),
        label:          "Membresía #{s.membership_type}",
        amount_cents:   s.amount_cents.to_i,
        payment_method: s.payment_method
      }
    end

    store_sales.each do |ss|
      @transactions << {
        at:             (ss.occurred_at || ss.created_at),
        label:          "Tienda (##{ss.id})",
        amount_cents:   ss.total_cents.to_i,
        payment_method: ss.payment_method
      }
    end

    # Agregamos los gastos a la lista del ticket
    expenses.each do |ex|
      @transactions << {
        at:             ex.occurred_at,
        label:          "SERVICIO: #{ex.description}",
        amount_cents:   -ex.amount_cents.to_i, # Negativo visualmente
        payment_method: "cash"
      }
    end

    @transactions.sort_by! { |h| h[:at] }

    # Detalle por producto
    items   = store_sales.flat_map { |ss| ss.store_sale_items.to_a }
    grouped = items.group_by(&:product_id)

    @sold_by_product = grouped.map do |product_id, arr|
      product        = arr.first&.product
      sold_qty       = arr.sum { |it| it.quantity.to_i }
      revenue_cents  = arr.sum { |it| it.unit_price_cents.to_i * it.quantity.to_i }

      {
        product:        product,
        product_name:   (product&.name.presence || "Producto ##{product_id}"),
        sold_qty:       sold_qty,
        revenue_cents:  revenue_cents,
        remaining_stock: product&.stock.to_i
      }
    end
    @sold_by_product.sort_by! { |h| -h[:sold_qty].to_i }
  end

  # ==========================
  # EXCEL (Actualizado con gastos)
  # ==========================
  def daily_export_excel
    day = Time.zone.today
    from, to = date_range_for(day, :day)
    filename = "reporte_#{day.strftime('%Y-%m-%d')}.xlsx"

    sales = Sale.where("COALESCE(sales.occurred_at, sales.created_at) BETWEEN ? AND ?", from, to).includes(:user, :client)
    store_sales = StoreSale.where("COALESCE(store_sales.occurred_at, store_sales.created_at) BETWEEN ? AND ?", from, to).includes(:user, store_sale_items: :product)
    expenses = Expense.where("occurred_at BETWEEN ? AND ?", from, to).includes(:user) # Gastos globales

    total_sales = sales.sum(:amount_cents).to_i + store_sales.sum(:total_cents).to_i
    total_expenses = expenses.sum(:amount_cents).to_i
    final_balance = total_sales - total_expenses

    pkg = Axlsx::Package.new
    wb  = pkg.workbook
    currency_fmt = wb.styles.add_style(num_fmt: 4)
    bold_style   = wb.styles.add_style(b: true)

    wb.add_worksheet(name: "Reporte General") do |ws|
      ws.add_row [ "Reporte Diario #{day}" ], style: [ bold_style ]
      ws.add_row [ "Ingresos Totales", (total_sales/100.0) ], style: [ nil, currency_fmt ]
      ws.add_row [ "Gastos/Servicios", (total_expenses/100.0) ], style: [ nil, currency_fmt ]
      ws.add_row [ "BALANCE FINAL", (final_balance/100.0) ], style: [ bold_style, currency_fmt ]
      ws.add_row []

      if expenses.any?
        ws.add_row [ "Detalle de Gastos" ], style: [ bold_style ]
        ws.add_row [ "Hora", "Usuario", "Descripción", "Monto" ], style: [ bold_style ]
        expenses.each do |ex|
           ws.add_row [ ex.occurred_at.strftime("%H:%M"), ex.user.name, ex.description, (ex.amount_cents/100.0) ], style: [ nil, nil, nil, currency_fmt ]
        end
      end
    end

    send_data pkg.to_stream.read, filename: filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # ... (daily_export CSV y history se mantienen similar, puedes usar la misma lógica) ...
  def daily_export; end
  def history; end

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
