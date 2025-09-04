# frozen_string_literal: true

module Jobs
  class LotteryScheduler < ::Jobs::Scheduled
    every 1.minute
    
    def execute(args)
      # 检查过期但未开奖的抽奖
      expired_lotteries = Lottery.active.expired.where(drawn_at: nil)
      
      expired_lotteries.find_each do |lottery|
        Rails.logger.info("Scheduling draw for expired lottery ##{lottery.id}")
        Jobs.enqueue(:draw_lottery, lottery_id: lottery.id)
      end
      
      # 清理旧的已完成抽奖数据（可选）
      if SiteSetting.lottery_cleanup_old_data
        cleanup_old_lotteries
      end
    end
    
    private
    
    def cleanup_old_lotteries
      # 删除超过1年的已完成抽奖
      cutoff_date = 1.year.ago
      old_lotteries = Lottery.where("status IN ('completed', 'cancelled') AND created_at < ?", cutoff_date)
      
      old_lotteries.find_each do |lottery|
        lottery.lottery_participants.delete_all
        lottery.lottery_winners.delete_all
        lottery.delete
      end
    end
  end
end
