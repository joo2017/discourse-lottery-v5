# db/migrate/001_create_lotteries.rb
class CreateLotteries < ActiveRecord::Migration[8.0]  # 注意版本号
  def change
    create_table :lotteries do |t|
      t.string :title, null: false, limit: 255
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :draw_type, default: 0, null: false
      t.integer :strategy_when_insufficient, default: 1, null: false
      t.integer :max_participants, null: false
      t.integer :min_participants, default: 1, null: false
      t.integer :prizes_count, default: 1, null: false
      t.datetime :deadline, null: false
      t.references :user, null: false, foreign_key: true
      t.references :topic, null: true, foreign_key: true
      t.json :prizes_data, default: {}
      t.json :drawing_settings, default: {}
      t.timestamps
    end
    
    add_index :lotteries, :status
    add_index :lotteries, :deadline
    add_index :lotteries, [:user_id, :status]
    add_index :lotteries, :draw_type
  end
end
