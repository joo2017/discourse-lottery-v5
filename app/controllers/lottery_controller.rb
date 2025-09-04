# app/controllers/lottery_controller.rb
class LotteryController < ApplicationController
  requires_login except: [:index, :show]
  before_action :find_lottery, only: [:show, :participate, :draw]
  
  def index
    lotteries = Lottery.available_for_participation
                     .includes(:user, :topic)
                     .limit(20)
                     .order(deadline: :asc)
    
    render json: MultiJson.dump({
      lotteries: serialize_data(lotteries, LotterySerializer),
      can_create: can_create_lottery?
    })
  end
  
  def participate
    raise Discourse::NotLoggedIn unless current_user
    
    if @lottery.can_participate?(current_user)
      LotteryParticipant.create!(
        lottery: @lottery,
        user: current_user,
        participated_at: Time.current
      )
      render json: { success: true }
    else
      render json: { error: I18n.t('lottery.cannot_participate') }
    end
  end
  
  private
  
  def find_lottery
    @lottery = Lottery.find(params[:id])
  end
  
  def can_create_lottery?
    current_user&.staff? || SiteSetting.lottery_allow_user_create
  end
end
