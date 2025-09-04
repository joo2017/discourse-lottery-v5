# frozen_string_literal: true

class CreateLotteryParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :lottery_participants do |t|
      t.references :lottery, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.inet :ip_address
      t.timestamp :participated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      
      t.timestamps null: false
      
      t.index [:lottery_id, :user_id], unique: true
      t.index [:user_id, :participated_at]
      t.index :ip_address
    end
  end
end
