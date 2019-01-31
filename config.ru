require 'dotenv'
Dotenv.load

require 'omniauth/strategies/github'
require 'octokit'
require 'dashing'

configure do
  set :auth_token, 'YOUR_AUTH_TOKEN'

  helpers do
    def protected!
      redirect '/auth/github' unless session[:user_id]
    end
  end

  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'read:org'
  end

  get '/auth/github/callback' do
    organization_id = ENV['GITHUB_ORG_ID']

    auth = request.env['omniauth.auth']

    client = Octokit::Client.new access_token: auth['credentials']['token']
    user_orgs = client.organization_memberships

    if user_orgs.any? { |org| org.organization.id.to_s == organization_id.to_s }
      # session[:user_id] = auth['info']['email']
      # using nickname instead since oauth apps can access public email only?
      session[:user_id] = auth['info']['nickname']
      redirect '/'
    else
      redirect '/auth/failure'
    end
  end

  get '/auth/failure' do
    'Nope.'
  end

end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
