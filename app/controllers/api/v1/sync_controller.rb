require "base64"

class Api::V1::SyncController < ApplicationController
  # 🛡️ IMPORTANTE: Permitimos que C# entre sin token de seguridad web
  skip_before_action :verify_authenticity_token, raise: false
  # Si usas Devise, es posible que necesites saltar la autenticación también para esta ruta
  # skip_before_action :authenticate_user!, raise: false

  def full_sync
    # 1. CLIENTES (Usamos tu modelo Client)
    clientes_data = Client.all.map do |c|
      {
        id: c.id,
        name: c.name,
        # Convertimos la huella binaria a texto Base64 estricto
        fingerprint_template: c.fingerprint.present? ? Base64.strict_encode64(c.fingerprint) : nil,
        expiration_date: c.next_payment_on, # Usamos tu campo real 'next_payment_on'
        registration_date: c.created_at,
        photo_path: c.photo.attached? ? url_for(c.photo) : nil
      }
    end

    # 2. PRODUCTOS (Modelo Product)
    productos_data = Product.all.map do |p|
      {
        id: p.id,
        name: p.name,
        price: p.price_cents.to_f / 100.0, # Convertimos centavos a pesos
        stock: p.stock
      }
    end

    # 3. USUARIOS (Modelo User - Devise)
    usuarios_data = User.all.map do |u|
      {
        name: u.email.split("@").first,
        password: u.encrypted_password,
        role: u.try(:admin?) ? "Admin" : "User"
      }
    end

    # 4. VENTAS (Modelo Sale - Últimos 30 días)
    ventas_data = Sale.where("created_at > ?", 30.days.ago).map do |s|
      {
        concept: "Venta ##{s.id}",
        total: s.amount_cents.to_f / 100.0, # Convertimos centavos a pesos
        payment_method: s.payment_method,
        date: s.occurred_at,
        username: s.user&.email || "Sistema"
      }
    end

    # ENVIAR TODO EL PAQUETE JSON
    render json: {
      clientes: clientes_data,
      productos: productos_data,
      usuarios: usuarios_data,
      ventas: ventas_data
    }
  end
end
