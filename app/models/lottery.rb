# app/models/lottery.rb
class Lottery < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic, optional: true
  has_many :lottery_participants, dependent: :destroy
  has_many :lottery_winners, dependent: :destroy
  
  # ✅ ActiveRecord 8.0 正确的 enum 语法
  enum :status, {
    draft: 0,        # 草稿 - 正在配置中
    active: 1,       # 活跃 - 接受报名参与
    drawing: 2,      # 抽奖中 - 正在执行抽奖
    completed: 3,    # 已完成 - 抽奖结束
    cancelled: 4     # 已取消 - 抽奖取消
  }, default: :draft
  
  enum :draw_type, {
    random: 0,           # 随机抽取
    specific_posts: 1,   # 基于特定帖子
    weighted: 2,         # 加权抽取
    first_come: 3        # 先到先得
  }, default: :random
  
  enum :strategy_when_insufficient, {
    cancel: 0,           # 取消抽奖
    proceed: 1,          # 继续进行
    extend_deadline: 2,  # 延长截止时间
    reduce_prizes: 3     # 减少奖品数量
  }, default: :proceed
  
  # 验证规则
  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :description, length: { maximum: 2000 }
  validates :max_participants, presence: true, numericality: { greater_than: 0 }
  validates :min_participants, presence: true, numericality: { greater_than: 0 }
  validates :deadline, presence: true
  validates :prizes_count, presence: true, numericality: { greater_than: 0 }
  
  # 自定义验证
  validate :deadline_in_future, on: :create
  validate :min_less_than_max_participants
  validate :prizes_count_not_exceed_max_participants
  
  # 作用域
  scope :available_for_participation, -> { where(status: :active).where('deadline > ?', Time.current) }
  scope :finished, -> { where(status: [:completed, :cancelled]) }
  scope :by_user, ->(user) { where(user: user) }
  
  # 实例方法
  def can_participate?(user = nil)
    return false unless active?
    return false if Time.current > deadline
    return false if max_participants_reached?
    return false if user && already_participated?(user)
    true
  end
  
  def max_participants_reached?
    lottery_participants.count >= max_participants
  end
  
  def sufficient_participants?
    lottery_participants.count >= min_participants
  end
  
  def already_participated?(user)
    lottery_participants.exists?(user: user)
  end
  
  def ready_for_drawing?
    active? && Time.current > deadline && sufficient_participants?
  end
  
  def participants_count
    lottery_participants.count
  end
  
  def winners_count
    lottery_winners.count
  end
  
  private
  
  def deadline_in_future
    return unless deadline
    errors.add(:deadline, 'must be in the future') if deadline <= Time.current
  end
  
  def min_less_than_max_participants
    return unless min_participants && max_participants
    if min_participants > max_participants
      errors.add(:min_participants, 'cannot be greater than max participants')
    end
  end
  
  def prizes_count_not_exceed_max_participants
    return unless prizes_count && max_participants
    if prizes_count > max_participants
      errors.add(:prizes_count, 'cannot exceed max participants')
    end
  end
end
