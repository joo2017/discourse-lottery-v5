# frozen_string_literal: true

class LotteryManager
  def initialize(lottery)
    @lottery = lottery
  end
  
  def eligible_participants
    return [] unless @lottery.active?
    
    case @lottery.draw_type
    when "random"
      random_eligible_participants
    when "specific_posts"
      specific_posts_eligible_participants
    else
      []
    end
  end
  
  def update_from_post(post)
    return false unless post.custom_fields["lottery_data"]
    
    data = JSON.parse(post.custom_fields["lottery_data"])
    return false unless data.is_a?(Hash)
    
    # 验证是否在后悔期内
    if @lottery.created_at + SiteSetting.lottery_post_lock_delay_minutes.minutes < Time.current
      return false
    end
    
    update_params = extract_update_params(data)
    @lottery.update(update_params)
  end
  
  def can_draw?
    return false unless @lottery.active?
    return false unless @lottery.expired?
    
    case @lottery.strategy_when_insufficient
    when "proceed"
      true
    when "cancel"
      @lottery.has_enough_participants?
    else
      @lottery.has_enough_participants?
    end
  end
  
  private
  
  def random_eligible_participants
    @lottery.lottery_participants
            .joins(:user)
            .where(users: { active: true, staged: false })
            .where.not(users: { id: excluded_user_ids })
            .includes(:user)
            .map(&:user)
  end
  
  def specific_posts_eligible_participants
    return [] unless @lottery.specific_posts.present?
    
    post_numbers = @lottery.specific_posts.split(",").map(&:strip).map(&:to_i)
    topic_posts = @lottery.topic.posts
                         .where(post_number: post_numbers)
                         .where.not(user_id: @lottery.user_id)
                         .joins(:user)
                         .where(users: { active: true, staged: false })
                         .where.not(users: { id: excluded_user_ids })
                         .includes(:user)
    
    topic_posts.map(&:user).uniq
  end
  
  def excluded_user_ids
    excluded_groups = SiteSetting.lottery_excluded_groups.split("|")
    return [] if excluded_groups.empty?
    
    User.joins(:groups)
        .where(groups: { name: excluded_groups })
        .distinct
        .pluck(:id)
  end
  
  def extract_update_params(data)
    {
      title: data["title"],
      description: data["description"],
      winner_count: data["winner_count"]&.to_i,
      min_participants: [data["min_participants"]&.to_i, SiteSetting.lottery_min_participants_global].max,
      end_time: Time.zone.parse(data["end_time"]),
      specific_posts: data["specific_posts"],
      strategy_when_insufficient: data["strategy_when_insufficient"],
      prize_info: data["prize_info"]
    }.compact
  end
end
