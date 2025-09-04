# plugin.rb
# frozen_string_literal: true

# name: discourse-lottery-v5
# about: 一个功能完整的 Discourse 抽奖插件系统
# version: 5.0.0
# authors: Discourse Lottery Team
# url: https://github.com/discourse-lottery/discourse-lottery-v5
# required_version: 3.2.0
# transpile_js: true

enabled_site_setting :lottery_enabled

register_asset "stylesheets/common/lottery.scss"
register_asset "stylesheets/desktop/lottery.scss", :desktop
register_asset "stylesheets/mobile/lottery.scss", :mobile

register_svg_icon "gift"
register_svg_icon "dice"
register_svg_icon "trophy"

module ::DiscourseLottery
  PLUGIN_NAME = "discourse-lottery-v5"
  
  class Engine < ::Rails::Engine
    engine_name DiscourseLottery::PLUGIN_NAME
    isolate_namespace DiscourseLottery
  end
end

after_initialize do
  # 加载模型
  require_relative "app/models/lottery"
  require_relative "app/models/lottery_participant"
  require_relative "app/models/lottery_winner"
  
  # 加载控制器
  require_relative "app/controllers/lottery_controller"
  
  # 加载任务
  require_relative "app/jobs/regular/draw_lottery"
  require_relative "app/jobs/regular/lock_lottery_post"
  require_relative "app/jobs/regular/notify_winners"
  require_relative "app/jobs/scheduled/lottery_scheduler"
  
  # 加载服务
  require_relative "app/services/lottery_creator"
  require_relative "app/services/lottery_manager"
  require_relative "app/services/lottery_draw_engine"
  
  # 加载序列化器
  require_relative "app/serializers/lottery_serializer"
  
  # 注册自定义字段类型
  register_post_custom_field_type("lottery_id", :integer)
  register_topic_custom_field_type("has_lottery", :boolean)
  register_topic_custom_field_type("lottery_data", :json)
  
  # 扩展序列化器
  add_to_serializer(:topic_view, :lottery) do
    if object.topic.custom_fields["has_lottery"]
      lottery = ::Lottery.find_by(topic_id: object.topic.id)
      if lottery
        ::LotterySerializer.new(lottery, scope: scope, root: false).as_json
      end
    end
  end
  
  add_to_serializer(:current_user, :lottery_stats) do
    {
      total_participations: object.lottery_participants.count,
      total_wins: object.lottery_winners.count,
      active_participations: object.lottery_participants.joins(:lottery).where(lotteries: { status: 0 }).count
    }
  end
  
  # 定义路由
  Discourse::Application.routes.append do
    scope "/lottery" do
      get "/" => "lottery#index", as: :lottery_index
      post "/create" => "lottery#create", as: :lottery_create
      post "/:id/participate" => "lottery#participate", as: :lottery_participate
      delete "/:id/leave" => "lottery#leave", as: :lottery_leave
      post "/:id/draw" => "lottery#draw", as: :lottery_draw
      get "/:id" => "lottery#show", as: :lottery_show
      put "/:id" => "lottery#update", as: :lottery_update
      delete "/:id" => "lottery#destroy", as: :lottery_destroy
      get "/user/:user_id/history" => "lottery#user_history", as: :lottery_user_history
      get "/statistics" => "lottery#statistics", as: :lottery_statistics
    end
    
    # 管理后台路由
    namespace :admin, constraints: AdminConstraint.new do
      scope "/plugins/lottery" do
        get "/" => "admin/lottery#index", as: :admin_lottery_index
        get "/:id" => "admin/lottery#show", as: :admin_lottery_show
        delete "/:id" => "admin/lottery#destroy", as: :admin_lottery_destroy
        post "/:id/draw" => "admin/lottery#draw", as: :admin_lottery_draw
        post "/:id/cancel" => "admin/lottery#cancel", as: :admin_lottery_cancel
        get "/:id/export_winners" => "admin/lottery#export_winners", as: :admin_lottery_export_winners
      end
    end
  end
  
  # 注册管理页面
  add_admin_route('lottery.admin.title', 'plugins.lottery')
  
  # 扩展模型
  reloadable_patch do |plugin|
    User.class_eval do
      has_many :lotteries, dependent: :destroy
      has_many :lottery_participants, dependent: :destroy
      has_many :lottery_winners, dependent: :destroy
      
      def can_participate_in_lottery?(lottery)
        return false unless lottery
        return false unless lottery.active?
        return false if lottery.expired?
        return false if lottery.participated?(self)
        return false if self == lottery.user
        return false if user_in_excluded_groups?
        
        true
      end
      
      private
      
      def user_in_excluded_groups?
        excluded_groups = SiteSetting.lottery_excluded_groups.split("|")
        return false if excluded_groups.empty?
        
        groups.where(name: excluded_groups).exists?
      end
    end

    Post.class_eval do
      has_one :lottery, dependent: :destroy
    end

    Topic.class_eval do
      has_many :lotteries, dependent: :destroy
    end
  end
  
  # 权限扩展
  add_to_class(:guardian, :can_create_lottery?) do
    return false unless user
    return false unless SiteSetting.lottery_enabled
    user.staff? || user.trust_level >= SiteSetting.lottery_require_trust_level
  end

  add_to_class(:guardian, :can_participate_in_lottery?) do |lottery|
    return false unless user
    return false unless SiteSetting.lottery_enabled
    user.can_participate_in_lottery?(lottery)
  end

  add_to_class(:guardian, :can_manage_lottery?) do |lottery|
    return false unless user
    return true if user.staff?
    return true if lottery&.user == user
    false
  end

  add_to_class(:guardian, :can_view_lottery_admin?) do
    user&.staff?
  end
  
  # 事件监听器
  on(:post_created) do |post, opts, user|
    if post.is_first_post? && post.custom_fields["lottery_data"]
      Jobs.enqueue(:create_lottery_from_post, post_id: post.id, user_id: user.id)
    end
  end
  
  on(:post_edited) do |post, topic_changed, user|
    if post.is_first_post? && post.custom_fields["lottery_data"]
      lottery = ::Lottery.find_by(post_id: post.id)
      if lottery && lottery.active?
        lock_time = lottery.created_at + SiteSetting.lottery_post_lock_delay_minutes.minutes
        if Time.current < lock_time
          Jobs.enqueue(:update_lottery_from_post, post_id: post.id, user_id: user.id)
        end
      end
    end
  end
end
