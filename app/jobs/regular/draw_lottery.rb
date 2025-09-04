# frozen_string_literal: true

module Jobs
  class DrawLottery < ::Jobs::Base
    def execute(args)
      lottery_id = args[:lottery_id]
      lottery = Lottery.find_by(id: lottery_id)
      
      return unless lottery
      return unless lottery.active?
      return unless lottery.expired?
      
      Rails.logger.info("Starting lottery draw for lottery ##{lottery_id}")
      
      begin
        lottery.draw!
        Rails.logger.info("Lottery draw completed for lottery ##{lottery_id}")
      rescue => e
        Rails.logger.error("Lottery draw failed for lottery ##{lottery_id}: #{e.message}")
        
        # 标记为失败状态
        lottery.update!(status: "cancelled")
        
        # 通知管理员
        notify_admin_of_failure(lottery, e.message)
      end
    end
    
    private
    
    def notify_admin_of_failure(lottery, error_message)
      admins = User.where(admin: true)
      admins.each do |admin|
        SystemMessage.create_from_system_user(
          admin,
          :lottery_draw_failed,
          lottery_title: lottery.title,
          lottery_id: lottery.id,
          error_message: error_message
        )
      end
    end
  end
end
