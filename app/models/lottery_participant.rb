# app/models/lottery_participant.rb
class LotteryParticipant < ActiveRecord::Base
  belongs_to :lottery
  belongs_to :user
  belongs_to :post, optional: true
  
  validates :user_id, uniqueness: { scope: :lottery_id }
  
  scope :by_lottery, ->(lottery) { where(lottery: lottery) }
end

# app/models/lottery_winner.rb  
class LotteryWinner < ActiveRecord::Base
  belongs_to :lottery
  belongs_to :user
  belongs_to :lottery_participant, optional: true
  
  enum :prize_status, {
    pending: 0,      # 待领取
    claimed: 1,      # 已领取
    expired: 2       # 已过期
  }, default: :pending
  
  validates :position, presence: true, uniqueness: { scope: :lottery_id }
end
