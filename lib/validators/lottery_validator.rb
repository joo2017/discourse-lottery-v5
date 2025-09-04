# frozen_string_literal: true

class AddIndexes < ActiveRecord::Migration[7.0]
  def change
    # 性能优化索引
    add_index :lotteries, [:status, :created_at], name: "index_lotteries_on_status_and_created_at"
    add_index :lotteries, [:topic_id, :status], name: "index_lotteries_on_topic_and_status"
    add_index :lottery_participants, [:lottery_id, :participated_at], name: "index_lottery_participants_on_lottery_and_time"
    add_index :lottery_winners, [:lottery_id, :drawn_at], name: "index_lottery_winners_on_lottery_and_time"
    
    # 用于清理任务的索引
    add_index :lotteries, [:status, :created_at], where: "status IN ('completed', 'cancelled')", 
              name: "index_lotteries_for_cleanup"
              
    # 用于统计的索引
    add_index :lotteries, :drawn_at, where: "drawn_at IS NOT NULL"
    add_index :lottery_participants, :participated_at
    
    # 复合索引优化查询性能
    add_index :lotteries, [:user_id, :status, :created_at], name: "index_lotteries_user_status_created"
    add_index :lottery_participants, [:user_id, :lottery_id], name: "index_lottery_participants_user_lottery"
  end
end
