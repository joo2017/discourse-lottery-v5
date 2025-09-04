# lib/discourse_lottery/engine.rb
# frozen_string_literal: true

module DiscourseLottery
  class Engine < ::Rails::Engine
    engine_name "discourse_lottery"
    isolate_namespace DiscourseLottery
  end
end
