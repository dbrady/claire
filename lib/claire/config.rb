# frozen_string_literal: true

require "yaml"
require "json"
require "fileutils"

module Claire
  class Config
    class NotFoundError < StandardError; end
    class MissingEntryError < StandardError; end

    attr_reader :site_name, :email, :api_token

    def initialize(site_name:, email:, api_token:)
      @site_name = site_name
      @email = email
      @api_token = api_token
    end

    def base_url
      "https://#{site_name}.atlassian.net"
    end

    def self.write!(path:, site_name:, email:, api_token:)
      FileUtils.mkdir_p(File.dirname(path))
      data = {
        "atlassian" => {
          "site_name" => site_name,
          "email" => email,
          "api_token" => api_token,
        },
        "user" => {
          "email" => email,
        },
      }
      File.write(path, YAML.dump(data))
    end

    def self.load(path: default_config_path)
      raise NotFoundError, "Config file not found: #{path}" unless File.exist?(path)

      data = YAML.load_file(path)
      atlassian = data.fetch("atlassian")
      new(
        site_name: atlassian.fetch("site_name"),
        email: atlassian.fetch("email"),
        api_token: atlassian.fetch("api_token"),
      )
    end

    def self.from_mcp_json(path: default_mcp_path)
      raise NotFoundError, "mcp.json not found: #{path}" unless File.exist?(path)

      data = JSON.parse(File.read(path))
      servers = data.dig("mcpServers") || {}
      confluence = servers["atlassian-confluence"]
      raise MissingEntryError, "No atlassian-confluence entry found in #{path}" if confluence.nil?

      env = confluence.fetch("env", {})
      {
        site_name: env.fetch("ATLASSIAN_SITE_NAME"),
        email: env.fetch("ATLASSIAN_USER_EMAIL"),
        api_token: env.fetch("ATLASSIAN_API_TOKEN"),
      }
    end

    def self.default_config_path
      File.expand_path("~/.config/claire/config.yml")
    end

    def self.default_resolutions_path
      File.expand_path("~/.config/claire/resolutions.yml")
    end

    def self.default_entries_path
      File.expand_path("~/.config/claire/entries.jsonl")
    end

    def self.default_mcp_path
      File.expand_path("~/.claude/.mcp.json")
    end
  end
end
