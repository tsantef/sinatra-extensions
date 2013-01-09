require 'sinatra/base'

module Sinatra
  module OAuth

    SCOPES = [
      'https://www.googleapis.com/auth/userinfo.email'
    ].join(' ')

    class << self
      attr_accessor :google_api_client
      attr_accessor :google_api_secret
      attr_accessor :github_api_client
      attr_accessor :github_api_secret
    end

    module Helpers
      def client
        client ||= OAuth2::Client.new(OAuth.google_api_client, OAuth.google_api_secret, {
          :site => 'https://accounts.google.com',
          :authorize_url => "/o/oauth2/auth",
          :token_url => "/o/oauth2/token"
        })
      end

      def redirect_uri(provider)
        uri = URI.parse(request.url)
        uri.path = "/oauth2callback/#{provider}"
        uri.query = nil
        uri.to_s
      end
    end

    def authenicated(&block)
      @@authenicated_block = block
    end

    def self.registered(app)
      app.helpers OAuth::Helpers

      get "/session/auth/:provider" do
        redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri(params[:provider]),:scope => SCOPES,:access_type => "offline")
      end

      get '/oauth2callback/:provider' do
        access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri(params[:provider]))
        if access_token
          provider = params[:provider]

          case provider
          when "google"
            user_info = access_token.get('https://www.googleapis.com/oauth2/v1/userinfo').parsed
            email = user_info['email']
            ident_key = "google-#{Digest::MD5.hexdigest(email)}"
            instance_exec provider, ident_key, email, email, &@@authenicated_block
          when "github"

          end
        end
      end
    end
  end

  register OAuth
end
