class ExpensesController < ApplicationController
  before_action :authenticate_user!

  def new
    @expense = Expense.new
  end

  def create
    # Convertimos el monto de pesos a centavos
    amount = (params[:expense][:amount].to_f * 100).to_i

    @expense = Expense.new(
      description: params[:expense][:description],
      amount_cents: amount,
      user: current_user,
      occurred_at: Time.current
    )

    if @expense.save
      redirect_to authenticated_root_path, notice: "Pago registrado: #{params[:expense][:description]} (-$#{params[:expense][:amount]})."
    else
      flash.now[:alert] = "Error al registrar. Revisa el monto."
      render :new
    end
  end
end
