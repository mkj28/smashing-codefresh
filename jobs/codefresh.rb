# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'
require 'time_difference'
require 'slack-ruby-client'
require 'redis'

CODEFRESH_API_TOKEN = ENV['CODEFRESH_API_TOKEN']

SUCCESS = 'Successful'
FAILED = 'Failed'

if ENV['REDIS_URL']
  redis_uri = URI.parse(ENV['REDIS_URL'])
  redis = Redis.new(host: redis_uri.host, port: redis_uri.port, password: redis_uri.password)
end

# initialize Slack
Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end
slack = Slack::Web::Client.new

SCHEDULER.every '10s', allow_overlapping: false do
  Pipelines::PIPELINE_LIST.each do |pipeline|
    send_event(pipeline['id'], get_build_health(pipeline, redis, slack))
  end
  Pipelines::CUSTOM_REPORTING_PIPELINE_LIST.each do |pipeline|
    send_event(pipeline['id'], get_build_health(pipeline, redis, slack))
  end
end

def calculate_health(successful_count, count)
  (successful_count / count.to_f * 100).round
end

def get_build_health(pipeline, redis, slack)
  service = pipeline['service']
  builds_to_fetch = pipeline['builds_to_fetch']
  branch_name = pipeline['branch_name']
  branch_name_regex = pipeline['branch_name_regex']
  slack_channel = pipeline['slack_channel']

  # ignore pending builds, filter by branch if provided
  url = "#{Pipelines::PIPELINE_CONFIG['codefresh_base_url']}/api/workflow/?limit=#{builds_to_fetch}&page=1&trigger=webhook&trigger=build&service=#{service}#{"&branchName=#{branch_name}" unless branch_name.nil?}&status=error&status=denied&status=success&status=approved&status=terminated"

  json = get_from_codefresh(url)

  builds = filter_builds(json, branch_name_regex)

  successful_count = builds.count { |build| build['status'] == 'success' }
  latest_build = builds.first
  # set the display name
  latest_build['displayName'] = pipeline['display_name'] ? pipeline['display_name'] : latest_build['repoName']

  duration = calculate_duration(latest_build['started'], latest_build['finished'])

  if !slack_channel.nil? && ENV['SLACK_API_TOKEN']
    # fetch previous build status and compare with current
    previous_status = redis.get(pipeline['id'])
    latest_status = latest_build['status']
    if latest_status != previous_status
      # notify slack if status changed
      notify_slack(slack, slack_channel, latest_build, previous_status)
    end
    # store current value
    redis.set(pipeline['id'], latest_status)
  end

  if pipeline['ifttt']
    notify_ifttt(latest_build['status'] == 'success', pipeline['ifttt'])
  end

  {
    display_name: latest_build['displayName'],
    name: latest_build['userName'],
    description: latest_build['commitMessage'].lines.first.truncate(55),
    status: latest_build['status'] == 'success' ? SUCCESS : FAILED,
    duration: duration,
    codefresh_link: "#{Pipelines::PIPELINE_CONFIG['codefresh_base_url']}/build/#{latest_build['id']}",
    github_link: latest_build['commitURL'],
    health: calculate_health(successful_count, builds.count),
    time: latest_build['started'],
    branch: latest_build['branchName'],
    show_branch_name: pipeline['show_branch_name']
  }
end

def notify_slack(slack, channel, build, previous_status)
  message = "#{build['displayName']} [#{build['branchName']}]: #{previous_status} --> #{build['status']}"\
  "\n #{Pipelines::PIPELINE_CONFIG['codefresh_base_url']}/build/#{build['id']}"\
  "\n #{build['userName']}: #{build['commitURL']}"
  slack.chat_postMessage(channel: channel, text: message, as_user: true)
end

def calculate_duration(started, finished)
  begin
    start_date = Time.parse started
  rescue StandardError => e
    start_date = Time.utc(1970)
  end
  begin
    end_date = Time.parse finished || Time.utc(1970)
  rescue StandardError => e
    end_date = Time.utc(1970)
  end
  TimeDifference.between(start_date, end_date).humanize
end

# filters builds if branch name regex provided
def filter_builds(json, branch_name_regex)
  builds = json['workflows']['docs']
  if branch_name_regex
    branch_regex = Regexp.new branch_name_regex
    builds = builds.select { |build| build['branchName'] =~ branch_regex }
  end

  builds
end

def get_from_codefresh(path)
  uri = URI.parse(path)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = CODEFRESH_API_TOKEN
  response = http.request(request)

  json = JSON.parse(response.body)
  json
end

def notify_ifttt(build_passed, ifttt_config)
  webhook_env_variable = ifttt_config['webhook_url_env']
  uri = URI.parse(ENV[webhook_env_variable])
  header = { 'Content-Type': 'application/json' }
  user = {
    value1: build_passed ? ifttt_config['value1_pass'] : ifttt_config['value1_fail'],
    value2: build_passed ? ifttt_config['value2_pass'] : ifttt_config['value2_fail']
  }

  # Create the HTTP objects
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = user.to_json

  # Send the request
  response = http.request(request)

  case response
  when Net::HTTPSuccess then
    # OK
  else
    puts "IFTTT request failed: #{response.code} #{response.message}: #{response.body}"
  end
end
