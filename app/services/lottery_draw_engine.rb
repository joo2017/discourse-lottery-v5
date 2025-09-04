# frozen_string_literal: true

class LotteryDrawEngine
  def initialize(lottery)
    @lottery = lottery
    @manager = LotteryManager.new(lottery)
  end
  
  def draw_winners
    eligible_users = @manager.eligible_participants
    return [] if eligible_users.empty?
    
    winner_count = [@lottery.winner_count, eligible_users.length].min
    
    case @lottery.draw_type
    when "random"
      draw_random_winners(eligible_users, winner_count)
    when "specific_posts"
      draw_specific_post_winners(eligible_users, winner_count)
    else
      []
    end
  end
  
  private
  
  def draw_random_winners(users, count)
    # 使用 Fisher-Yates 洗牌算法确保公平性
    seed = generate_verifiable_seed
    rng = Random.new(seed)
    
    shuffled_users = users.dup
    (shuffled_users.length - 1).downto(1) do |i|
      j = rng.rand(i + 1)
      shuffled_users[i], shuffled_users[j] = shuffled_users[j], shuffled_users[i]
    end
    
    winners = shuffled_users.first(count)
    
    # 保存抽奖种子用于验证
    @lottery.update!(
      draw_seed: seed.to_s,
      verification_data: generate_verification_data(winners, seed)
    )
    
    winners
  end
  
  def draw_specific_post_winners(users, count)
    # 对于指定楼层，按楼层号排序选择
    post_numbers = @lottery.specific_posts.split(",").map(&:strip).map(&:to_i).sort
    
    winners = []
    post_numbers.each do |post_num|
      break if winners.length >= count
      
      post = @lottery.topic.posts.find_by(post_number: post_num)
      if post && users.include?(post.user)
        winners << post.user
        users.delete(post.user)  # 避免重复
      end
    end
    
    # 如果指定楼层的获奖者不足，从剩余用户中随机选择
    remaining_count = count - winners.length
    if remaining_count > 0 && users.any?
      additional_winners = draw_random_winners(users, remaining_count)
      winners.concat(additional_winners)
    end
    
    winners
  end
  
  def generate_verifiable_seed
    # 生成可验证的随机种子
    timestamp = Time.current.to_f
    lottery_data = "#{@lottery.id}-#{@lottery.end_time}-#{@lottery.participant_count}"
    
    Digest::SHA256.hexdigest("#{timestamp}-#{lottery_data}").to_i(16) % (2**32)
  end
  
  def generate_verification_data(winners, seed)
    {
      seed: seed,
      timestamp: Time.current.iso8601,
      lottery_id: @lottery.id,
      winner_ids: winners.map(&:id),
      participant_count: @lottery.lottery_participants.count,
      algorithm: "fisher_yates_shuffle"
    }.to_json
  end
end
