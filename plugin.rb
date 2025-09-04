# plugin.rb
# name: discourse-lottery
# about: Lottery system for Discourse communities
# version: 2.0.0
# authors: Your Name
# url: https://github.com/your-username/discourse-lottery
# required_version: 3.2.0
# transpile_js: true

enabled_site_setting :lottery_enabled

register_asset 'stylesheets/lottery.scss'
register_svg_icon 'gift'
register_svg_icon 'dice'

module ::DiscourseeLottery
  PLUGIN_NAME = 'discourse-lottery'
end

require_relative 'lib/discourse_lottery/engine'

after_initialize do
  # 模型自动加载（Rails 8.0 推荐方式）
  # 不需要手动 require，Rails 会自动加载 app/ 目录下的文件
  
  # 注册路由
  Discourse::Application.routes.append do
    get '/admin/plugins/lottery' => 'lottery_admin#index'
    get '/lottery' => 'lottery#index'
    post '/lottery/:id/participate' => 'lottery#participate'
    post '/lottery/:id/draw' => 'lottery#draw'
  end
  
  # 添加导航菜单
  register_top_menu_item('lottery') if respond_to?(:register_top_menu_item)
  
  # 权限定义
  add_admin_route('lottery.title', 'lottery')
  
  # 用户模型扩展
  reloadable_patch do |plugin|
    ::User.class_eval do
      has_many :lotteries, dependent: :destroy
      has_many :lottery_participants, dependent: :destroy
      has_many :lottery_winners, dependent: :destroy
    end
  end
end
