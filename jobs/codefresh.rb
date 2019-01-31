require 'net/http'
require 'json'
require 'time'
require 'time_difference'

CODEFRESH_API_TOKEN = ENV["CODEFRESH_API_TOKEN"]

SUCCESS = 'Successful'
FAILED = 'Failed'

SCHEDULER.every '10s' do
  Builds::BUILD_LIST.each do |build|
    send_event(build['repoName'], get_build_health(build))
  end
end

def calculate_health(successful_count, count)
  return (successful_count / count.to_f * 100).round
end

def get_build_health(build)
  repo_name = build['repoName']
  repo_owner = build['repoOwner']
  service_name = build['serviceName']

  # ignore pending builds
  url = "#{Builds::BUILD_CONFIG['codefreshBaseUrl']}/api/workflow/?limit=20&page=1&trigger=webhook&trigger=build&repoOwner=#{repo_owner}&repoName=#{repo_name}&provider=github&serviceName=#{service_name}&branchName=master&pageSize=20&status=error&status=denied&status=success&status=approved&status=terminated"

  json = getFromCodefresh(url)


  docs_array = json['workflows']['docs']

  # filter to the pipeline we want to monitor
  builds_with_service = docs_array.select { |build| build['serviceName'] == service_name }

  successful_count = builds_with_service.count { |build| build['status'] == 'success' }
  latest_build = builds_with_service.first

  start_date = Time.parse latest_build['started']
  end_date = Time.parse latest_build['finished']

  duration =  TimeDifference.between(start_date, end_date).humanize

  return {
    name: latest_build['userName'],
    description: latest_build['commitMessage'].lines.first.truncate(55),
    status: latest_build['status'] == 'success' ? SUCCESS : FAILED,
    duration: duration,
    codefresh_link: "#{Builds::BUILD_CONFIG['codefreshBaseUrl']}/build/#{latest_build['id']}",
    github_link: latest_build['commitURL'],
    health: calculate_health(successful_count, builds_with_service.count),
    time: latest_build['started']
  }
end

def getFromCodefresh(path)

  uri = URI.parse(path)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  request['x-access-token'] = CODEFRESH_API_TOKEN
  response = http.request(request)

  json = JSON.parse(response.body)
  return json
end
