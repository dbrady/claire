# frozen_string_literal: true

require "claire/config"
require "claire/jira"

module Claire
  module CLI
    class Init
      def initialize(config_path: Claire::Config.default_config_path,
                     mcp_path: Claire::Config.default_mcp_path,
                     jira_class: Claire::Jira)
        @config_path = config_path
        @mcp_path = mcp_path
        @jira_class = jira_class
      end

      def run
        if File.exist?(@config_path)
          warn "claire: config already exists at #{@config_path}"
          warn "Remove it manually if you want to re-initialize."
          exit 1
        end

        credentials = Claire::Config.from_mcp_json(path: @mcp_path)
        Claire::Config.write!(path: @config_path, **credentials)
        puts "Wrote #{@config_path}"

        config = Claire::Config.load(path: @config_path)
        display_name = @jira_class.new(config).ping_myself
        puts "Authenticated as: #{display_name}"
      rescue Claire::Jira::AuthenticationError => e
        warn "Authentication failed (HTTP #{e.status}): #{e.body}"
        exit 1
      end
    end
  end
end
