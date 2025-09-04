# frozen_string_literal: true

class Lottery < ActiveRecord::Base
  belongs_to :post
  belongs_to :topic
  belongs_to :user
  
  has_many :lottery_participants, dependent: :destroy
  has_many :lottery_winners, dependent: :destroy
  has_many :participants, through: :lottery_participants, source: :user
  has_many :winners, through: :lottery_winners, source: :user
  
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :winner_count, presence: true, numericality: { greater_than: 0 }
  validates :min_participants, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :end_time, presence: true
  validates :draw_type, inclusion: { in: %w[random specific_posts] }
  validates :status, inclusion: { in: %w[active completed cancelled] }
  
  validate :end_time_must_be_future, on: :create
  validate :winner_count_must_not_exceed_participants
  validate :specific_posts_format, if: :specific_posts_draw?
  
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :expired, -> { where("end_time < ?", Time.current) }
  
  before_create :set_defaults
  after_create :schedule_draw_job
  after_update :reschedule_jobs, if: :saved_change_to_end_time?
  
  def expired?
    end_time < Time.current
  end
  
  def can_participate?(user)
    return false unless user
    return false unless active?
    return false if expired?
    return false if participated?(user)
    return false if user == self.user
    return false if user_in_excluded_groups?(user)
    
    true
  end
  
  def participated?(user)
    lottery_participants.exists?(user: user)
  end
  
  def active?
    status == "active"
  end
  
  def completed?
    status == "completed"
  end
  
  def cancelled?
    status == "cancelled"
  end
  
  def specific_posts_draw?
    draw_type == "specific_posts"
  end
  
  def random_draw?
    draw_type == "random"
  end
  
  def has_enough_participants?
    lottery_participants.count >= min_participants
  end
  
  def draw!
    return false unless can_draw?
    
    case strategy_when_insufficient
    when "proceed"
      perform_draw
    when "cancel"
      if has_enough_participants?
        perform_draw
      else
        cancel_lottery
      end
    else
      perform_draw if has_enough_participants?
    end
  end
  
  def can_draw?
    active? && expired?
  end
  
  def time_remaining
    return 0 if expired?
    end_time - Time.current
  end
  
  def winners_list
    lottery_winners.includes(:user).order(:position).map(&:user)
  end
  
  private
  
  def set_defaults
    self.status ||= "active"
    self.created_at ||= Time.current
  end
  
  def schedule_draw_job
    Jobs.enqueue_at(end_time, :draw_lottery, lottery_id: id)
    
    if SiteSetting.lottery_post_lock_delay_minutes > 0
      lock_time = created_at + SiteSetting.lottery_post_lock_delay_minutes.minutes
      Jobs.enqueue_at(lock_time, :lock_lottery_post, lottery_id: id)
    end
  end
  
  def reschedule_jobs
    # 取消旧任务并重新安排
    Sidekiq::Cron::Job.destroy("draw_lottery_#{id}")
    schedule_draw_job
  end
  
  def perform_draw
    engine = LotteryDrawEngine.new(self)
    winners = engine.draw_winners
    
    if winners.any?
      create_winners(winners)
      self.update!(status: "completed", drawn_at: Time.current)
      notify_winners
    else
      cancel_lottery
    end
  end
  
  def cancel_lottery
    self.update!(status: "cancelled")
    notify_cancellation
  end
  
  def create_winners(users)
    users.each_with_index do |user, index|
      lottery_winners.create!(
        user: user,
        position: index + 1,
        drawn_at: Time.current
      )
    end
  end
  
  def notify_winners
    Jobs.enqueue(:notify_winners, lottery_id: id)
  end
  
  def notify_cancellation
    # 发布取消通知
    MessageBus.publish("/lottery/#{id}", {
      type: "cancelled",
      lottery_id: id
    })
  end
  
  def user_in_excluded_groups?(user)
    excluded_groups = SiteSetting.lottery_excluded_groups.split("|")
    return false if excluded_groups.empty?
    
    user.groups.where(name: excluded_groups).exists?
  end
  
  def end_time_must_be_future
    if end_time && end_time <= Time.current
      errors.add(:end_time, I18n.t("lottery.errors.end_time_must_be_future"))
    end
  end
  
  def winner_count_must_not_exceed_participants
    if winner_count && min_participants && winner_count > min_participants
      errors.add(:winner_count, I18n.t("lottery.errors.winner_count_exceeds_participants"))
    end
  end
  
  def specific_posts_format
    return unless specific_posts.present?
    
    posts = specific_posts.split(",").map(&:strip)
    posts.each do |post_num|
      unless post_num.match?(/^\d+$/)
        errors.add(:specific_posts, I18n.t("lottery.errors.invalid_post_format"))
        break
      end
    end
  end
end
