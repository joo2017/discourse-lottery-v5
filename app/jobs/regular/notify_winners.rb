# frozen_string_literal: true

module Jobs
  class NotifyWinners < ::Jobs::Base
    def execute(args)
      lottery_id = args[:lottery_id]
      lottery = Lottery.find_by(id: lottery_id)
      
      return unless lottery&.completed?
      
      lottery.lottery_winners.includes(:user).each do |winner|
        create_notification(winner)
        send_private_message(winner) if should_send_pm?(winner.user)
      end
      
      # 在帖子中公布结果
      post_results_announcement(lottery)
      
      # 发布实时更新
      MessageBus.publish("/lottery/#{lottery.id}", {
        type: "draw_completed",
        lottery_id: lottery.id,
        winners: lottery.lottery_winners.includes(:user).map do |winner|
          {
            user_id: winner.user_id,
            username: winner.user.username,
            position: winner.position
          }
        end
      })
    end
    
    private
    
    def create_notification(winner)
      winner.user.notifications.create!(
        notification_type: Notification.types[:custom],
        data: {
          message: "lottery.winner_notification",
          lottery_id: winner.lottery.id,
          lottery_title: winner.lottery.title,
          position: winner.position
        }.to_json
      )
    end
    
    def should_send_pm?(user)
      user.user_option.email_always? ||
      user.user_option.email_level == UserOption.email_level_types[:always]
    end
    
    def send_private_message(winner)
      PostCreator.create!(
        Discourse.system_user,
        title: I18n.t("lottery.pm.winner_title"),
        raw: I18n.t("lottery.pm.winner_body",
                   lottery_title: winner.lottery.title,
                   position: winner.position,
                   topic_url: "#{Discourse.base_url}/t/#{winner.lottery.topic.slug}/#{winner.lottery.topic.id}"),
        archetype: Archetype.private_message,
        target_usernames: [winner.user.username]
      )
    end
    
    def post_results_announcement(lottery)
      winners_text = lottery.lottery_winners.includes(:user).order(:position).map do |winner|
        "#{winner.position}. @#{winner.user.username}"
      end.join("\n")
      
      raw = I18n.t("lottery.results.announcement",
                  lottery_title: lottery.title,
                  winner_count: lottery.lottery_winners.count,
                  winners: winners_text)
      
      PostCreator.create!(
        Discourse.system_user,
        topic_id: lottery.topic_id,
        raw: raw,
        reply_to_post_number: lottery.post.post_number
      )
    end
  end
end
