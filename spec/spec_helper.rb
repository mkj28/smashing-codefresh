require 'rspec'
require 'webmock/rspec'
require 'uri'

def require_job path
  require File.expand_path '../../jobs/' + path, __FILE__
end

class SCHEDULER
  def self.every(ignoreone, ignoretwo)
  end
end

module Pipelines
  PIPELINE_CONFIG = {
    "codefresh_base_url" => 'https://codefresh'
  }
end

RSpec.configure do |config|
  config.color = true
  config.order = 'random'
end
