# frozen_string_literal: true

class LotteryWinner < ActiveRecord::Base
  belongs_to :lottery
  belongs_to :user
  belongs_to :lottery_participant, optional: true
  
  validates :lottery_id, presence: true
  validates :user_id, presence: true
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :lottery_id }
  
  scope :ordered, -> { order(:position) }
  
  before_create :set_drawn_at
  
  private
  
  def set_drawn_at
    self.drawn_at = Time.current
  end
end
