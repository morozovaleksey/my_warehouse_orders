class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.string :uuid
      t.string :good_id
      t.string :agent_id
      t.float :quantity
      t.timestamps null: false
    end
  end
end
