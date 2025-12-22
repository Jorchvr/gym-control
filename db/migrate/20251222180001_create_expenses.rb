class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.string :description
      t.integer :amount_cents
      t.references :user, null: false, foreign_key: true
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
