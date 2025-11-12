# db/seeds.rb

def safe_assign(record, attrs)
  attrs.each do |k, v|
    setter = "#{k}="
    record.public_send(setter, v) if record.respond_to?(setter)
  end
end

if ActiveRecord::Base.connection.table_exists?(:users)
  # Crea/actualiza un admin sin usar columnas que quizá no existan (p.ej. secret_code)
  def upsert_user!(email:, name:, password:, superuser: false, role: 0)
    u = User.find_or_initialize_by(email: email)
    safe_assign(u, {
      name: name,
      password: password,
      password_confirmation: password,
      superuser: superuser,
      role: role
    })
    u.save!
    puts "Seeded user: #{u.email} (id=#{u.id})"
  end

  upsert_user!(
    email: "admin@gym.local",
    name:  "Admin",
    password: "Admin123!",
    superuser: true,
    role: 0
  )

  # Si antes tenías scripts que “arreglan” roles nulos, protégelos:
  if User.column_names.include?("role")
    fixed = User.where(role: nil).update_all(role: 0)
    puts "→ Usuarios arreglados con role=NULL → role=0: #{fixed}"
  end
else
  puts "Tabla users no existe aún; se seedeará en la próxima corrida tras migraciones."
end
