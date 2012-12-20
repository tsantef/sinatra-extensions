require 'sinatra/base'

module Sinatra
  module BasicAuth

    module Helpers
      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
          halt_error 401, "Not authorized"
        end
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        if settings.users && @auth.provided? && @auth.basic? && @auth.credentials
          if settings.users.has_key?(@auth.credentials[0])
            return @auth.credentials[1] == settings.users[@auth.credentials[0]]
          end
        end
        false
      end

      def halt_error(code, message, data={})
        logger.error "#{code} - #{message}"
        halt code,
          {'Content-Type' => 'application/json'},
          {'message' => message, 'data' => data}.to_json
      end
    end

    def self.registered(app)
      app.helpers BasicAuth::Helpers
    end

  end

  register BasicAuth
end
