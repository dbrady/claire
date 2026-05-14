# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"

module Claire
  class Jira
    class AuthenticationError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body = body
        super("Authentication failed (HTTP #{status}): #{body}")
      end
    end

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def ping_myself
      uri = URI("#{config.base_url}/rest/api/3/myself")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["Authorization"] = basic_auth_header

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 5
        http.read_timeout = 10
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)["displayName"]
      else
        raise AuthenticationError.new(response.code, response.body)
      end
    end

    private

    def basic_auth_header
      credentials = Base64.strict_encode64("#{config.email}:#{config.api_token}")
      "Basic #{credentials}"
    end
  end
end
