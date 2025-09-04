# frozen_string_literal: true

module Jobs
  class LockLotteryPost < ::Jobs::Base
    def execute(args)
      lottery_id = args[:lottery_id]
      lottery = Lottery.find_by(id: lottery_id)
      
      return unless lottery
      return unless lottery.post
      return if lottery.post.locked?
      
      lottery.post.update!(locked_by_id: Discourse.system_user.id)
      
      StaffActionLogger.new(Discourse.system_user).log_post_lock(
        lottery.post,
        { locked: true }
      )
      
      Rails.logger.info("Locked post ##{lottery.post.id} for lottery ##{lottery_id}")
    end
  end
end
