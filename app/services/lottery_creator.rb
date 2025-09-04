# frozen_string_literal: true

class LotteryCreator
  def initialize(user:, topic:, params:)
    @user = user
    @topic = topic
    @params = params
  end
  
  def create
    ActiveRecord::Base.transaction do
      lottery = build_lottery
      
      if lottery.save
        create_lottery_post(lottery)
        setup_topic_custom_fields
        lottery
      else
        lottery
      end
    end
  end
  
  private
  
  def build_lottery
    # 智能判断抽奖方式
    if @params[:specific_posts].present?
      posts_array = parse_specific_posts(@params[:specific_posts])
      @params[:draw_type] = "specific_posts"
      @params[:winner_count] = posts_array.length if posts_array.any?
    else
      @params[:draw_type] = "random"
    end
    
    # 应用全局最小参与人数限制
    global_min = SiteSetting.lottery_min_participants_global
    if @params[:min_participants].to_i < global_min
      @params[:min_participants] = global_min
    end
    
    Lottery.new(@params.merge(
      user: @user,
      topic: @topic,
      status: "active"
    ))
  end
  
  def create_lottery_post(lottery)
    post = @topic.posts.first
    
    if post
      lottery.update!(post: post)
      post.custom_fields["lottery_id"] = lottery.id
      post.save_custom_fields(true)
    end
  end
  
  def setup_topic_custom_fields
    @topic.custom_fields["has_lottery"] = true
    @topic.save_custom_fields(true)
  end
  
  def parse_specific_posts(posts_string)
    return [] if posts_string.blank?
    
    posts_string.split(",").map(&:strip).select { |p| p.match?(/^\d+$/) }.map(&:to_i)
  end
end
