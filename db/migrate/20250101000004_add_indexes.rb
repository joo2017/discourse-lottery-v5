# frozen_string_literal: true

class AddIndexes < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:lotteries) && 
                  table_exists?(:lottery_participants) && 
                  table_exists?(:lottery_winners)
    
    # 性能优化索引 - 只在索引不存在时添加
    unless index_exists?(:lotteries, [:status, :created_at], name: "index_lotteries_on_status_and_created_at")
      add_index :lotteries, [:status, :created_at], name: "index_lotteries_on_status_and_created_at"
    end
    
    unless index_exists?(:lotteries, [:topic_id, :status], name: "index_lotteries_on_topic_and_status")
      add_index :lotteries, [:topic_id, :status], name: "index_lotteries_on_topic_and_status"
    end
    
    unless index_exists?(:lottery_participants, [:lottery_id, :participated_at], name: "index_lottery_participants_on_lottery_and_time")
      add_index :lottery_participants, [:lottery_id, :participated_at], name: "index_lottery_participants_on_lottery_and_time"
    end
    
    unless index_exists?(:lottery_winners, [:lottery_id, :drawn_at], name: "index_lottery_winners_on_lottery_and_time")
      add_index :lottery_winners, [:lottery_id, :drawn_at], name: "index_lottery_winners_on_lottery_and_time"
    end
    
    # 用于清理任务的索引
    unless index_exists?(:lotteries, [:status, :created_at], name: "index_lotteries_for_cleanup")
      add_index :lotteries, [:status, :created_at], where: "status IN ('completed', 'cancelled')", 
                name: "index_lotteries_for_cleanup"
    end
                
    # 用于统计的索引
    unless index_exists?(:lotteries, :drawn_at)
      add_index :lotteries, :drawn_at, where: "drawn_at IS NOT NULL"
    end
    
    unless index_exists?(:lottery_participants, :participated_at)
      add_index :lottery_participants, :participated_at
    end
    
    # 复合索引优化查询性能
    unless index_exists?(:lotteries, [:user_id, :status, :created_at], name: "index_lotteries_user_status_created")
      add_index :lotteries, [:user_id, :status, :created_at], name: "index_lotteries_user_status_created"
    end
    
    unless index_exists?(:lottery_participants, [:user_id, :lottery_id], name: "index_lottery_participants_user_lottery")
      add_index :lottery_participants, [:user_id, :lottery_id], name: "index_lottery_participants_user_lottery"
    end
  end
  
  def down
    # 在 down 方法中移除索引
    remove_index :lotteries, name: "index_lotteries_on_status_and_created_at" if index_exists?(:lotteries, name: "index_lotteries_on_status_and_created_at")
    remove_index :lotteries, name: "index_lotteries_on_topic_and_status" if index_exists?(:lotteries, name: "index_lotteries_on_topic_and_status")
    remove_index :lottery_participants, name: "index_lottery_participants_on_lottery_and_time" if index_exists?(:lottery_participants, name: "index_lottery_participants_on_lottery_and_time")
    remove_index :lottery_winners, name: "index_lottery_winners_on_lottery_and_time" if index_exists?(:lottery_winners, name: "index_lottery_winners_on_lottery_and_time")
    remove_index :lotteries, name: "index_lotteries_for_cleanup" if index_exists?(:lotteries, name: "index_lotteries_for_cleanup")
    remove_index :lotteries, :drawn_at if index_exists?(:lotteries, :drawn_at)
    remove_index :lottery_participants, :participated_at if index_exists?(:lottery_participants, :participated_at)
    remove_index :lotteries, name: "index_lotteries_user_status_created" if index_exists?(:lotteries, name: "index_lotteries_user_status_created")
    remove_index :lottery_participants, name: "index_lottery_participants_user_lottery" if index_exists?(:lottery_participants, name: "index_lottery_participants_user_lottery")
  end
end
