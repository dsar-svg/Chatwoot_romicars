# frozen_string_literal: true

class CreateProductInquiries < ActiveRecord::Migration[7.0]
  def change
    create_table :product_inquiries do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :canal, limit: 50
      t.string :marca_buscada, limit: 100
      t.string :modelo_buscado, limit: 100
      t.text :repuesto_buscado
      t.boolean :encontrado, null: false, default: false
      t.text :descripcion_encontrada

      t.timestamps
    end

    add_index :product_inquiries, :repuesto_buscado, name: 'idx_product_inquiries_repuesto'
    add_index :product_inquiries, :canal, name: 'idx_product_inquiries_canal'
    add_index :product_inquiries, [:marca_buscada, :modelo_buscado], name: 'idx_product_inquiries_marca_modelo'
  end
end
