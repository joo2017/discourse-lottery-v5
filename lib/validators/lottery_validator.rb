# frozen_string_literal: true

class LotteryValidator
  include ActiveModel::Validations
  
  attr_accessor :title, :description, :winner_count, :min_participants, :end_time,
                :draw_type, :specific_posts, :strategy_when_insufficient, :prize_info
  
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :prize_info, length: { maximum: 1000 }
  validates :winner_count, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validates :min_participants, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }
  validates :end_time, presence: true
  validates :draw_type, inclusion: { in: %w[random specific_posts] }
  validates :strategy_when_insufficient, inclusion: { in: %w[cancel proceed] }
  
  validate :end_time_must_be_future
  validate :min_participants_must_meet_global_requirement
  validate :winner_count_must_not_exceed_participants
  validate :specific_posts_format, if: :specific_posts_draw?
  validate :user_can_create_lottery
  
  def initialize(params, user)
    @user = user
    
    params.each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end
  end
  
  private
  
  def end_time_must_be_future
    return unless end_time.present?
    
    parsed_time = Time.zone.parse(end_time.to_s)
    if parsed_time <= Time.current
      errors.add(:end_time, I18n.t("lottery.errors.end_time_must_be_future"))
    end
  rescue ArgumentError
    errors.add(:end_time, I18n.t("lottery.errors.invalid_time_format"))
  end
  
  def min_participants_must_meet_global_requirement
    global_min = SiteSetting.lottery_min_participants_global
    if min_participants && min_participants < global_min
      errors.add(:min_participants, I18n.t("lottery.errors.min_participants_too_low", min: global_min))
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
    unless posts.all? { |post| post.match?(/^\d+$/) }
      errors.add(:specific_posts, I18n.t("lottery.errors.specific_posts_format"))
    end
  end
  
  def specific_posts_draw?
    draw_type == "specific_posts"
  end
  
  def user_can_create_lottery
    return unless @user
    
    # 检查信任等级
    required_tl = SiteSetting.lottery_require_trust_level
    if @user.trust_level < required_tl
      errors.add(:base, I18n.t("lottery.errors.insufficient_trust_level", required: required_tl))
    end
    
    # 检查活跃抽奖数量限制
    active_count = Lottery.where(user: @user, status: "active").count
    max_active = SiteSetting.lottery_max_active_per_user
    if active_count >= max_active
      errors.add(:base, I18n.t("lottery.errors.too_many_active_lotteries", max: max_active))
    end
    
    # 检查创建频率限制
    if SiteSetting.lottery_rate_limit_creates > 0
      recent_count = Lottery.where(user: @user)
                           .where('created_at > ?', 1.day.ago)
                           .count
      if recent_count >= SiteSetting.lottery_rate_limit_creates
        errors.add(:base, I18n.t("lottery.errors.create_rate_limit_exceeded"))
      end
    end
  end
end
