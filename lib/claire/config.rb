# frozen_string_literal: true

require "yaml"
require "json"
require "fileutils"

module Claire
  class Config
    class NotFoundError < StandardError; end
    class MissingEntryError < StandardError; end

    attr_reader :site_name, :email, :api_token, :data_dir

    def initialize(site_name:, email:, api_token:, data_dir: nil)
      @site_name = site_name
      @email = email
      @api_token = api_token
      @data_dir = data_dir || self.class.default_data_dir(config: nil)
    end

    def base_url
      "https://#{site_name}.atlassian.net"
    end

    def self.write!(path:, site_name:, email:, api_token:, data_dir: nil)
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
      data["data_dir"] = data_dir if data_dir
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
        data_dir: data["data_dir"],
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

    def self.default_config_dir
      if ENV["XDG_CONFIG_HOME"] && !ENV["XDG_CONFIG_HOME"].empty?
        File.join(ENV["XDG_CONFIG_HOME"], "claire")
      else
        File.expand_path("~/.config/claire")
      end
    end

    def self.default_config_path
      File.join(default_config_dir, "config.yml")
    end

    # Returns the data directory to use.
    #
    # Priority: explicit value on a loaded Config > XDG_DATA_HOME > hardcoded default.
    # Pass config: nil (or omit it) when no Config has been loaded yet (e.g. during init).
    def self.default_data_dir(config: nil)
      return config.data_dir if config && config.data_dir

      xdg = ENV["XDG_DATA_HOME"]
      return File.join(xdg, "claire") if xdg && !xdg.empty?

      File.expand_path("~/.local/share/claire")
    end

    def self.default_aliases_path(config: nil)
      File.join(default_data_dir(config: config), "aliases.yml")
    end

    def self.default_approvals_path(config: nil)
      File.join(default_data_dir(config: config), "approvals.yml")
    end

    def self.default_project_names_path(config: nil)
      File.join(default_data_dir(config: config), "project_names.yml")
    end

    def self.default_resolutions_path(config: nil)
      File.join(default_data_dir(config: config), "resolutions.yml")
    end

    def self.default_entries_path(config: nil)
      File.join(default_data_dir(config: config), "entries.jsonl")
    end

    def self.default_mcp_path
      File.expand_path("~/.claude/.mcp.json")
    end
  end
end
