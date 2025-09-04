# frozen_string_literal: true

class ::LotteryController < ApplicationController
  before_action :ensure_logged_in
  before_action :ensure_lottery_enabled
  before_action :find_lottery, except: [:index, :create]
  before_action :check_can_participate, only: [:participate]
  
  def index
    page = params[:page].to_i.clamp(1, 50)
    per_page = 20
    
    lotteries = Lottery.includes(:user, :topic)
                      .order(created_at: :desc)
                      .offset((page - 1) * per_page)
                      .limit(per_page)
    
    render json: {
      lotteries: serialize_data(lotteries, LotterySerializer),
      meta: {
        page: page,
        per_page: per_page,
        total_count: Lottery.count
      }
    }
  end
  
  def show
    render json: serialize_data(@lottery, LotterySerializer, 
                               include_participants: true,
                               include_winners: @lottery.completed?)
  end
  
  def create
    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::NotFound unless topic
    raise Discourse::InvalidAccess unless guardian.can_create_post?(topic)
    
    lottery_params = params.require(:lottery).permit(
      :title, :description, :winner_count, :min_participants,
      :end_time, :draw_type, :specific_posts, :strategy_when_insufficient,
      :require_trust_level, :prize_info
    )
    
    # 验证参数
    validator = LotteryValidator.new(lottery_params, current_user)
    unless validator.valid?
      return render_json_error(validator.errors.full_messages.first)
    end
    
    lottery = LotteryCreator.new(
      user: current_user,
      topic: topic,
      params: lottery_params
    ).create
    
    if lottery.persisted?
      render json: serialize_data(lottery, LotterySerializer), status: :created
    else
      render_json_error(lottery.errors.full_messages)
    end
  rescue => e
    Rails.logger.error("Lottery creation failed: #{e.message}")
    render_json_error(I18n.t("lottery.errors.creation_failed"))
  end
  
  def participate
    participant = @lottery.lottery_participants.build(user: current_user)
    
    if participant.save
      # 发布参与事件
      MessageBus.publish("/lottery/#{@lottery.id}", {
        type: "participant_joined",
        lottery_id: @lottery.id,
        participant_count: @lottery.lottery_participants.count
      })
      
      render json: { 
        success: true, 
        participant_count: @lottery.lottery_participants.count,
        message: I18n.t("lottery.participate.success")
      }
    else
      render_json_error(participant.errors.full_messages)
    end
  end
  
  def leave
    participant = @lottery.lottery_participants.find_by(user: current_user)
    
    if participant&.destroy
      MessageBus.publish("/lottery/#{@lottery.id}", {
        type: "participant_left",
        lottery_id: @lottery.id,
        participant_count: @lottery.lottery_participants.count
      })
      
      render json: { 
        success: true, 
        participant_count: @lottery.lottery_participants.count,
        message: I18n.t("lottery.leave.success")
      }
    else
      render_json_error(I18n.t("lottery.leave.not_participating"))
    end
  end
  
  def draw
    raise Discourse::InvalidAccess unless guardian.can_moderate?(@lottery.topic)
    raise Discourse::InvalidAccess unless @lottery.can_draw?
    
    if @lottery.draw!
      render json: serialize_data(@lottery.reload, LotterySerializer, include_winners: true)
    else
      render_json_error(I18n.t("lottery.draw.failed"))
    end
  end
  
  def update
    raise Discourse::InvalidAccess unless can_edit_lottery?
    
    lottery_params = params.require(:lottery).permit(
      :title, :description, :winner_count, :min_participants,
      :end_time, :specific_posts, :strategy_when_insufficient,
      :prize_info
    )
    
    if @lottery.update(lottery_params)
      render json: serialize_data(@lottery, LotterySerializer)
    else
      render_json_error(@lottery.errors.full_messages)
    end
  end
  
  def destroy
    raise Discourse::InvalidAccess unless can_delete_lottery?
    
    @lottery.update!(status: "cancelled")
    render json: { success: true }
  end
  
  private
  
  def ensure_lottery_enabled
    raise Discourse::NotFound unless SiteSetting.lottery_enabled
  end
  
  def find_lottery
    @lottery = Lottery.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise Discourse::NotFound
  end
  
  def check_can_participate
    unless @lottery.can_participate?(current_user)
      render_json_error(I18n.t("lottery.errors.cannot_participate"))
    end
  end
  
  def can_edit_lottery?
    return true if guardian.is_admin?
    return true if @lottery.user == current_user && @lottery.active?
    false
  end
  
  def can_delete_lottery?
    return true if guardian.is_admin?
    return true if @lottery.user == current_user
    false
  end
end
