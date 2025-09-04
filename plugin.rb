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
  
  # 注册自定义字段
  register_post_custom_field_type("lottery_id", :integer)
  register_topic_custom_field_type("has_lottery", :boolean)
  
  # 扩展 TopicViewSerializer
  add_to_serializer(:topic_view, :lottery) do
    if object.topic.custom_fields["has_lottery"]
      lottery = ::Lottery.find_by(topic_id: object.topic.id)
      if lottery
        ::LotterySerializer.new(lottery, scope: scope, root: false).as_json
      end
    end
  end
  
  # 路由
  Discourse::Application.routes.append do
    namespace :lottery, path: "/lottery" do
      get "/" => "lottery#index"
      post "/create" => "lottery#create"
      post "/:id/participate" => "lottery#participate"
      delete "/:id/leave" => "lottery#leave"
      post "/:id/draw" => "lottery#draw"
      get "/:id" => "lottery#show"
      put "/:id" => "lottery#update"
      delete "/:id" => "lottery#destroy"
    end
    
    # 管理路由
    namespace :admin, constraints: AdminConstraint.new do
      get "/lottery" => "admin/lottery#index"
      get "/lottery/:id" => "admin/lottery#show"
      delete "/lottery/:id" => "admin/lottery#destroy"
    end
  end
  
  # 事件监听
  on(:post_created) do |post, opts, user|
    if post.is_first_post? && post.custom_fields["lottery_data"]
      Jobs.enqueue(:create_lottery_from_post, post_id: post.id)
    end
  end
  
  on(:post_edited) do |post, topic_changed, user|
    if post.is_first_post? && post.custom_fields["lottery_data"]
      lottery = ::Lottery.find_by(post_id: post.id)
      if lottery && lottery.status == "active"
        Jobs.enqueue(:update_lottery_from_post, post_id: post.id)
      end
    end
  end
end
