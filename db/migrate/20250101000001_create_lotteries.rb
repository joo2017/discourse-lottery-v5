# frozen_string_literal: true

class CreateLotteries < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:lotteries)
    
    create_table :lotteries do |t|
      t.references :post, null: false, foreign_key: true, index: true
      t.references :topic, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      t.string :title, null: false, limit: 255
      t.text :description
      t.text :prize_info
      t.integer :winner_count, null: false, default: 1
      t.integer :min_participants, null: false, default: 5
      t.integer :participant_count, null: false, default: 0
      
      t.timestamp :end_time, null: false
      t.timestamp :drawn_at
      
      t.string :draw_type, null: false, default: 'random', limit: 50
      t.text :specific_posts
      t.string :strategy_when_insufficient, null: false, default: 'cancel', limit: 50
      
      t.string :status, null: false, default: 'active', limit: 20
      t.text :draw_seed
      t.text :verification_data
      
      t.timestamps null: false
      
      t.index [:status, :end_time]
      t.index [:user_id, :status]
      t.index :created_at
    end
    
    add_check_constraint :lotteries, "winner_count > 0", name: "lotteries_winner_count_positive"
    add_check_constraint :lotteries, "min_participants > 0", name: "lotteries_min_participants_positive"
    add_check_constraint :lotteries, "status IN ('active', 'completed', 'cancelled')", name: "lotteries_status_valid"
    add_check_constraint :lotteries, "draw_type IN ('random', 'specific_posts')", name: "lotteries_draw_type_valid"
    add_check_constraint :lotteries, "strategy_when_insufficient IN ('cancel', 'proceed')", name: "lotteries_strategy_valid"
  end
  
  def down
    drop_table :lotteries if table_exists?(:lotteries)
  end
end
