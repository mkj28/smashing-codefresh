module Builds
    BUILD_CONFIG = JSON.parse(File.read('config/builds.json'))
    BUILD_LIST = BUILD_CONFIG['builds']
    CUSTOM_REPORTING_BUILD_LIST = BUILD_CONFIG['custom_reporting_builds']
end
