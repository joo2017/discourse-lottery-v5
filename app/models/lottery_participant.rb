# frozen_string_literal: true

class LotteryParticipant < ActiveRecord::Base
  belongs_to :lottery
  belongs_to :user
  
  validates :lottery_id, presence: true
  validates :user_id, presence: true
  validates :lottery_id, uniqueness: { scope: :user_id }
  
  scope :valid_participants, -> { joins(:user).where(users: { active: true, staged: false }) }
  
  before_create :set_participated_at
  after_create :update_participant_count
  after_destroy :update_participant_count
  
  private
  
  def set_participated_at
    self.participated_at = Time.current
  end
  
  def update_participant_count
    lottery.update_column(:participant_count, lottery.lottery_participants.count)
  end
end
