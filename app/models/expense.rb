class Expense < ApplicationRecord
  belongs_to :user

  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true
end
