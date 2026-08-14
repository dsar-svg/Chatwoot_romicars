# frozen_string_literal: true

class Faq < ApplicationRecord
  belongs_to :account

  validates :question, presence: true
  validates :answer, presence: true
  validates :question, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_search, lambda { |search|
    where('question ILIKE :q OR answer ILIKE :q OR keywords ILIKE :q', q: "%#{search}%") if search.present?
  }
  scope :ordered, -> { order(priority: :desc, created_at: :desc) }

  CATEGORIES = %w[repuestos envios garantias pagos general].freeze
end
