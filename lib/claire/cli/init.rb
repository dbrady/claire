# frozen_string_literal: true

require "fileutils"
require "claire/config"
require "claire/jira"

module Claire
  module CLI
    class Init
      LEGACY_DATA_FILENAMES = ["entries.jsonl", "resolutions.yml"].freeze

      STARTER_ALIASES = <<~YAML
        # Edit this file to add project-code aliases, or use `claire alias add`.
        # Each entry maps a short name to a Clarity project code.
        EXAMPLE: PR00000
      YAML

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

        data_dir = Claire::Config.default_data_dir(config: nil)
        FileUtils.mkdir_p(data_dir)

        old_config_dir = File.dirname(@config_path)
        self.class.migrate_legacy_data!(
          from: old_config_dir,
          to: data_dir,
          filenames: LEGACY_DATA_FILENAMES,
        )

        Claire::Config.write!(path: @config_path, data_dir: data_dir, **credentials)
        puts "Wrote #{@config_path}"

        seed_aliases_file!(data_dir: data_dir)

        config = Claire::Config.load(path: @config_path)
        display_name = @jira_class.new(config).ping_myself
        puts "Authenticated as: #{display_name}"
      rescue Claire::Jira::AuthenticationError => e
        warn "Authentication failed (HTTP #{e.status}): #{e.body}"
        exit 1
      end

      private

      def seed_aliases_file!(data_dir:)
        path = File.join(data_dir, "aliases.yml")
        return if File.exist?(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, STARTER_ALIASES)
        puts "Wrote #{path}"
      end

      # Moves data files from the old config-dir layout into the new data dir.
      # For each filename: if the file exists in `from` but not in `to`, moves it.
      # Prints a header on first move and one line per moved file, with aligned arrows.
      # output: an IO object (defaults to $stdout)
      def self.migrate_legacy_data!(from:, to:, filenames:, output: $stdout)
        sources = filenames.map { |f| File.join(from, f) }
        destinations = filenames.map { |f| File.join(to, f) }

        pairs = sources.zip(destinations).select do |source, destination|
          File.exist?(source) && !File.exist?(destination)
        end

        return if pairs.empty?

        width = pairs.map { |source, _| source.length }.max
        output.puts "Migrating data files from legacy location:"
        pairs.each do |source, destination|
          output.puts "  #{source.ljust(width)} -> #{destination}"
          FileUtils.mv(source, destination)
        end
      end
    end
  end
end
