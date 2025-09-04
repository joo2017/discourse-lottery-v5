# frozen_string_literal: true

module DiscourseLottery
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseLottery
    
    config.autoload_paths << File.join(config.root, "lib")
    
    initializer "discourse_lottery.assets" do
      Rails.application.config.assets.paths << File.expand_path("../../../assets", __FILE__)
    end
  end
end
