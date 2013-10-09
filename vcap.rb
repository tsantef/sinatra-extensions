require 'sinatra/base'

module Sinatra
  module Vcap

    def vcap
      settings.vcap
    end

    def first_instance?
      (not vcap.application.instance_index) || (not vcap.application.instance_index > 0)
    end

    def mysql_service(version, service_name=nil)
      service = vcap_service("mysql-" + version, service_name)
      creds = OpenStruct.new(service['credentials'])
      url  = ["mysql2://"]
      url << "#{creds.username}:#{creds.password}"
      url << "@#{creds.host}:#{creds.port}"
      url << "/#{creds.name}"
      Sequel.connect url.join('')
    end

    def postgres_service(version, service_name=nil)
      service = vcap_service("postgresql-" + version, service_name)
      creds = OpenStruct.new(service['credentials'])
      url  = ["postgres://"]
      url << "#{creds.username}:#{creds.password}"
      url << "@#{creds.host}:#{creds.port}"
      url << "/#{creds.name}"
      Sequel.connect url.join('')
    end

    def vcap_service(service_type, service_name=nil)
      services = vcap.services[service_type]
      if !service_name.nil?
        service = services.detect{|s| s['name'] == service_name }
      else
        service = services.first
      end
      service
    end

    def self.registered(app)
      app.set :vcap, OpenStruct.new({
        application: OpenStruct.new(JSON.parse(ENV.fetch('VCAP_APPLICATION', "{}"))),
        services: JSON.parse(ENV.fetch('VCAP_SERVICES', "{}"))
      })
    end

  end

  register Vcap
end
