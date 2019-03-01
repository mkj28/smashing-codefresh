# frozen_string_literal: true

module Pipelines
  PIPELINE_CONFIG = JSON.parse(File.read('config/pipelines.json'))
  PIPELINE_LIST = PIPELINE_CONFIG['pipelines']
  CUSTOM_REPORTING_PIPELINE_LIST = PIPELINE_CONFIG['custom_reporting_pipelines']
end
