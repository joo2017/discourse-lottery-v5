# frozen_string_literal: true

class CreateLotteryWinners < ActiveRecord::Migration[7.0]
  def change
    create_table :lottery_winners do |t|
      t.references :lottery, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.references :lottery_participant, null: true, foreign_key: true, index: true
      
      t.integer :position, null: false
      t.timestamp :drawn_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.text :verification_hash
      
      t.timestamps null: false
      
      t.index [:lottery_id, :position], unique: true
      t.index [:user_id, :drawn_at]
    end
    
    add_check_constraint :lottery_winners, "position > 0", name: "lottery_winners_position_positive"
  end
end
