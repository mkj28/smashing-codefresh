require 'net/http'
require 'json'
require 'time'
require 'time_difference'

CODEFRESH_API_TOKEN = ENV["CODEFRESH_API_TOKEN"]

SUCCESS = 'Successful'
FAILED = 'Failed'

SCHEDULER.every '30s', allow_overlapping: false do
  Builds::BUILD_LIST.each do |build|
    send_event(build['id'], get_build_health(build))
  end
  Builds::CUSTOM_REPORTING_BUILD_LIST.each do |build|
    send_event(build['id'], get_build_health(build))
  end
end

def calculate_health(successful_count, count)
  return (successful_count / count.to_f * 100).round
end

def get_build_health(build)
  service = build['service']
  builds_to_fetch = build['builds_to_fetch']
  branch_name = build['branch_name']
  branch_name_regex = build['branch_name_regex']

  # ignore pending builds, filter by branch if provided
  url = "#{Builds::BUILD_CONFIG['codefreshBaseUrl']}/api/workflow/?limit=#{builds_to_fetch}&page=1&trigger=webhook&trigger=build&service=#{service}#{"&branchName=#{branch_name}" unless branch_name.nil?}&status=error&status=denied&status=success&status=approved&status=terminated"

  json = getFromCodefresh(url)

  builds = json['workflows']['docs']

  # branch name regex provided
  if branch_name_regex
    branch_regex = Regexp.new branch_name_regex
    builds = builds.select { |build| build['branchName'] =~ branch_regex }
  end

  successful_count = builds.count { |build| build['status'] == 'success' }
  latest_build = builds.first

  begin
    start_date = Time.parse latest_build['started']
  rescue => e
    puts "Failed fetching start_date for #{service}: #{e}"
    start_date = Time.new(1970)
  end
  begin
    end_date = Time.parse latest_build['finished'] || Time.new(1970)
  rescue => e
    puts "Failed fetching end_date for #{service}: #{e}"
    end_date = Time.new(1970)
  end
  duration =  TimeDifference.between(start_date, end_date).humanize

  return {
    repo: latest_build['repoName'],
    name: latest_build['userName'],
    description: latest_build['commitMessage'].lines.first.truncate(55),
    status: latest_build['status'] == 'success' ? SUCCESS : FAILED,
    duration: duration,
    codefresh_link: "#{Builds::BUILD_CONFIG['codefreshBaseUrl']}/build/#{latest_build['id']}",
    github_link: latest_build['commitURL'],
    health: calculate_health(successful_count, builds.count),
    time: latest_build['started'],
    # only show branch if regex provided
    branch: branch_name_regex ? latest_build['branchName'] : nil
  }
end

def getFromCodefresh(path)

  uri = URI.parse(path)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = CODEFRESH_API_TOKEN
  response = http.request(request)

  json = JSON.parse(response.body)
  return json
end
