# frozen_string_literal: true

class CreateFaqs < ActiveRecord::Migration[7.0]
  def change
    create_table :faqs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :question, null: false
      t.text :answer, null: false
      t.string :category
      t.string :keywords
      t.boolean :active, default: true, null: false
      t.integer :priority, default: 0, null: false

      t.timestamps
    end

    add_index :faqs, [:account_id, :active]
    add_index :faqs, [:account_id, :category]
  end
end
