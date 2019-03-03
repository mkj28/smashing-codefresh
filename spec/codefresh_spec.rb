# frozen_string_literal: true

require 'spec_helper.rb'
require_job 'codefresh.rb'

describe 'get build data from codefresh' do
  before(:each) do
    @codefresh_response = {
      'workflows' => {
        'docs' => [
          {
            "started": '2019-03-01T23:39:38.219Z',
            "finished": '2019-03-02T00:01:26.130Z',
            "status": 'success',
            "userName": 'smashing',
            "commitMessage": 'added lavalamp support'
          }
        ]
      }
    }

    stub_request(:get, 'https://codefresh/api/workflow/?').with(query: hash_including({}))
                                                          .to_return(status: 200, body: @codefresh_response.to_json, headers: {})
  end

  it 'should get build info from codefresh' do
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name' => 'master', 'builds_to_fetch' => 10 }, nil, nil)
    expect(WebMock.a_request(:get, 'https://codefresh/api/workflow/?branchName=master&limit=10&page=1&service=333&status=terminated&trigger=build')).to have_been_made
  end

  it 'should return the name of the commiter that trigerred the build' do
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name' => 'master', 'builds_to_fetch' => 10 }, nil, nil)
    expect(build_health[:name]).to eq('smashing')
  end

  it 'should return the status of the latest build when Successful' do
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name' => 'master', 'builds_to_fetch' => 10 }, nil, nil)
    expect(build_health[:status]).to eq('Successful')
  end

  it 'should return the build duration' do
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name' => 'master', 'builds_to_fetch' => 10 }, nil, nil)
    expect(build_health[:duration]).to eq('21 Minutes and 47 Seconds')
  end

  it 'should return the status of the latest build when Failed' do
    failed_build = {
      'workflows' => {
        'docs' => [
          {
            "status": 'error',
            "branchName": '1.2.3',
            "commitMessage": 'added slack support'
          }
        ]
      }
    }
    stub_request(:get, 'https://codefresh/api/workflow/?').with(query: hash_including({}))
                                                          .to_return(status: 200, body: failed_build.to_json, headers: {})
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name_regex' => '\\d\\.\\d\\.\\d', 'builds_to_fetch' => 10 }, nil, nil)
    expect(build_health[:status]).to eq('Failed')
  end

  it 'should return the build health' do
    mixed_results = {
      'workflows' => {
        'docs' => [
          {
            "status": 'error',
            "commitMessage": 'errored'
          },
          {
            "status": 'success',
            "commitMessage": 'passed'
          },
          {
            "status": 'success',
            "commitMessage": 'I passed too'
          }
        ]
      }
    }
    stub_request(:get, 'https://codefresh/api/workflow/?').with(query: hash_including({}))
                                                          .to_return(status: 200, body: mixed_results.to_json, headers: {})
    build_health = get_build_health({ 'id' => 'p1', 'service' => '333', 'branch_name' => 'master', 'builds_to_fetch' => 10 }, nil, nil)
    expect(build_health[:health]).to eq(67)
  end
end

describe 'builds filtering' do
  before(:each) do
    @codefresh_response = {
      'workflows' => {
        'docs' => [
          { 'branchName' => '1.2.3' },
          { 'branchName' => 'mybranch/ch12345' }
        ]
      }
    }
  end

  it 'returns all builds if no filter provided' do
    filtered_builds = filter_builds(@codefresh_response, nil)
    expect(filtered_builds).to eq(@codefresh_response['workflows']['docs'])
  end

  it 'returns builds matching regular expression' do
    filtered_builds = filter_builds(@codefresh_response, '\\d\\.\\d\\.\\d')
    expect(filtered_builds[0]['branchName']).to eq('1.2.3')
  end
end

describe 'duration calculation' do
  it 'calculates duration if both start and finish provided' do
    calculated_duration = calculate_duration('2019-03-01T23:39:38.219Z', '2019-03-02T00:01:26.130Z')
    expect(calculated_duration).to eq('21 Minutes and 47 Seconds')
  end

  it 'calculates duration even if start missing' do
    calculated_duration = calculate_duration(nil, '1970-01-01T00:01:00.000Z')
    expect(calculated_duration).to eq('1 Minute')
  end
end
