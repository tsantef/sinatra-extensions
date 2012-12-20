require 'sinatra/base'
require 'sinatra-logentries'
require 'active_support/inflector'

module ApiResource

  def self.included(klass)
    klass.send(:include, ApiResource::Methods)
    klass.send(:extend, ApiResource::Methods)
  end

  module Methods

    @@resource_id = :id
    def set_resource_id(resource_id)
      @@resource_id = resource_id
    end

    def uri(base="")
      base + "/" + self.class.name.pluralize.downcase + '/' + self.send(@@resource_id).to_s
    end

  end
end

module Sinatra
  module JsonAPI

    module Helpers
      def api_base_url
        if settings.api_version.empty?
          request.base_url
        else
          request.base_url + "/" + settings.api_version
        end
      end

      def page_index(default=nil)
        if !default.nil?
          request_assert(params[:page_index].nil? || params[:page_index].to_i > 0, "page index")
          params[:page_index] = (params[:page_index] || default).to_i
        end
        params[:page_index]
      end

      def page_size(default=nil)
        if !default.nil?
          request_assert(params[:page_size].nil? || params[:page_size].to_i > 0, "page size")
          params[:page_size] = (params[:page_size] || default).to_i
        end
        params[:page_size]
      end

      def format_response(data)
        preferred_type = ""
        if !params[:format].nil? && params[:format].length > 1
          preferred_type = "*/" + params[:format]
        else
          preferred_type = request.preferred_type('*/json', '*/html')
        end
        case preferred_type
        when '*/html'
          content_type :html
          '<pre>' + JSON.pretty_generate(data) + '</pre>'
        else
          content_type :json
          data.to_json
        end
      end

      def respond(data={}, code=nil)
        if code.nil?
          if data.is_a? Integer
            status data
          elsif data.nil?
            status 204
          else
            status 200
            format_response(data)
          end
        else
          status code
          format_response(data) unless data.nil?
        end
      end

      def respond_with_data(data, opts={}, code=200)
        payload = opts
        payload['data'] = data
        respond payload, code
      end

      def halt_error(code, message=nil, data=nil)
        logger.warn("#{code} - #{message}") if code >= 500
        payload = {}
        payload['message'] = message unless message.nil?
        payload['data'] = data unless data.nil?
        halt code, {'Content-Type' => 'application/json'}, payload.to_json
      end

      def halt_404(message=nil, data=nil)
        message ||= "Not Found"
        halt_error(404, message, data)
      end

      def request_assert(condition, message=nil)
        if condition != true
          if message
            halt_error 400, "Bad Request: " + message
          else
            halt_error 400, "Bad Request"
          end
        end
      end

      def get_columns(all, default=nil)
        default ||= all
        if !params[:columns].nil? && params[:columns].length > 0
          if params[:columns][0] == "*"
            all
          else
            params[:columns] & all
          end
        else
          default
        end
      end
    end

    def api_version(v)
      set :api_version, v
    end

    def get_param_columns
      if @wildcard_columns.nil?
        return "*"
      elsif !params[:columns].nil?
        return URI::encode(params[:columns].join(','))
      else
        return ""
      end
    end

    def get_json(path, options={}, &block)
      options[:provides] = ['json', 'html']
      url_prefix = ""
      url_prefix = '/' + settings.api_version unless settings.api_version.empty?
      all_columns = options[:all_columns]
      options.delete(:all_columns) if !options[:all_columns].nil?
      get url_prefix + path + "\.?:format?", options do
        # make column array
        if !params[:columns].nil?
          params[:columns] = params[:columns].split(",").map { |p| p.strip }.select { |p| !p.empty? }
        else
          params[:columns] = []
        end
        # expand all columns
        if params[:columns].length > 0 && params[:columns][0] == "*"
          @wildcard_columns = true
          params[:columns] = all_columns || []
        else
          params[:columns] = params[:columns].map { |p| p.to_sym }
          params[:columns] = params[:columns] & all_columns if !all_columns.nil?
        end
        instance_eval &block
      end
    end

    def put_json(path, options={}, &block)
      options[:provides] = ['json', 'html']
      url_prefix = ""
      url_prefix = '/' + settings.api_version unless settings.api_version.empty?
      put url_prefix + path, options do
        instance_eval &block
      end
    end

    def delete_json(path, options={}, &block)
      options[:provides] = ['json', 'html']
      url_prefix = ""
      url_prefix = '/' + settings.api_version unless settings.api_version.empty?
      delete url_prefix + path, options do
        instance_eval &block
      end
    end

    def self.registered(app)
      app.helpers JsonAPI::Helpers

      app.set :method do |*methods|
        condition { methods.map(&:upcase).include? request.request_method }
      end

      app.set :accept do |type|
        condition { request.content_type == type }
      end

      app.before method: %w(post put patch) do
        begin
          body = JSON.parse(request.body.read)
        rescue JSON::ParserError
          error_message = "Problems parsing JSON"
        end
        if error_message or ! body.kind_of?(Hash)
          error_message ||= 'Body should be a JSON hash'
          halt 400, {'Content-Type' => 'application/json'},
            {'message' => error_message}.to_json
        end
        @body = OpenStruct.new(body)
      end
    end
  end

  register JsonAPI
end