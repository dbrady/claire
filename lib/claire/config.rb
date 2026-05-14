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

    def self.default_data_dir
      config_path = default_config_path
      if File.exist?(config_path)
        data = YAML.load_file(config_path)
        explicit = data["data_dir"] if data.is_a?(Hash)
        return explicit if explicit && !explicit.empty?
      end

      if ENV["XDG_DATA_HOME"] && !ENV["XDG_DATA_HOME"].empty?
        File.join(ENV["XDG_DATA_HOME"], "claire")
      else
        File.expand_path("~/.local/share/claire")
      end
    end

    def self.default_resolutions_path
      File.join(default_data_dir, "resolutions.yml")
    end

    def self.default_entries_path
      File.join(default_data_dir, "entries.jsonl")
    end

    def self.default_mcp_path
      File.expand_path("~/.claude/.mcp.json")
    end

    # Moves data files from the old config-dir layout into the new data dir.
    # For each filename: if the file exists in `from` but not in `to`, moves it.
    # Prints a header on first move and one line per moved file.
    # output: an IO object (defaults to $stdout)
    def self.migrate_legacy_data!(from:, to:, filenames:, output: $stdout)
      header_printed = false

      filenames.each do |filename|
        source = File.join(from, filename)
        destination = File.join(to, filename)

        next unless File.exist?(source)
        next if File.exist?(destination)

        unless header_printed
          output.puts "Migrating data files from legacy location:"
          header_printed = true
        end

        output.puts "  #{source}    -> #{destination}"
        FileUtils.mv(source, destination)
      end
    end
  end
end
