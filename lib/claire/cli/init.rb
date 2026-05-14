# frozen_string_literal: true

require "claire/config"
require "claire/jira"

module Claire
  module CLI
    class Init
      CONFIG_PATH = Claire::Config.default_config_path
      MCP_PATH = Claire::Config.default_mcp_path

      def initialize(config_path: CONFIG_PATH, mcp_path: MCP_PATH, jira_class: Claire::Jira)
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
        result = @jira_class.new(config).ping_myself

        if result[:success]
          puts "Authenticated as: #{result[:display_name]}"
        else
          warn "Authentication failed (HTTP #{result[:status]}): #{result[:body]}"
          exit 1
        end
      end
    end
  end
end
