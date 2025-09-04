# frozen_string_literal: true

class LotterySerializer < ApplicationSerializer
  attributes :id, :title, :description, :winner_count, :min_participants,
             :end_time, :draw_type, :specific_posts, :status, :created_at,
             :participant_count, :time_remaining, :can_participate, :user_participated,
             :prize_info, :strategy_when_insufficient
  
  has_one :user, serializer: BasicUserSerializer
  has_one :topic, serializer: BasicTopicSerializer
  
  def include_participants?
    options[:include_participants]
  end
  
  def include_winners?
    options[:include_winners]
  end
  
  def participants
    return [] unless include_participants?
    
    object.lottery_participants.includes(:user).limit(100).map do |participant|
      BasicUserSerializer.new(participant.user, root: false)
    end
  end
  
  def winners
    return [] unless include_winners?
    
    object.lottery_winners.includes(:user).order(:position).map do |winner|
      {
        user: BasicUserSerializer.new(winner.user, root: false),
        position: winner.position,
        drawn_at: winner.drawn_at
      }
    end
  end
  
  def time_remaining
    object.time_remaining.to_i
  end
  
  def can_participate
    return false unless scope&.user
    object.can_participate?(scope.user)
  end
  
  def user_participated
    return false unless scope&.user
    object.participated?(scope.user)
  end
  
  def participant_count
    object.lottery_participants.count
  end
end
