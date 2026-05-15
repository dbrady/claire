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

      STARTER_PROJECT_NAMES = <<~YAML
        # Edit this file to add project names. Each entry maps a Clarity project
        # code to a human-readable name. Used by claire log, check, and report.
        PREXAMPLE: Example project name
      YAML

      STARTER_APPROVALS = <<~YAML
        # Each entry records that you've manually verified Clarity approval
        # for a project code. Use `claire approve <code>` to add entries.
        # Stored as ISO-8601 timestamps; claire check displays the date.
        PREXAMPLE: "2026-01-01T00:00:00+00:00"
      YAML

      def initialize(config_path: Claire::Config.default_config_path,
                     mcp_path: Claire::Config.default_mcp_path,
                     jira_class: Claire::Jira)
        @config_path = config_path
        @mcp_path = mcp_path
        @jira_class = jira_class
      end

      def run
        data_dir = Claire::Config.default_data_dir(config: nil)

        # Legacy upgrade path: config.yml already exists in the old config-dir
        # location but the data dir has not been created yet. This is the expected
        # state for a user upgrading from a pre-S13 claire. Migrate data files,
        # rewrite the config to include data_dir, then finish the normal init
        # steps. Do NOT refuse — this is not a re-init, it is an upgrade.
        if File.exist?(@config_path) && !File.exist?(data_dir)
          FileUtils.mkdir_p(data_dir)

          old_config_dir = File.dirname(@config_path)
          self.class.migrate_legacy_data!(
            from: old_config_dir,
            to: data_dir,
            filenames: LEGACY_DATA_FILENAMES,
          )

          existing = Claire::Config.load(path: @config_path)
          Claire::Config.write!(
            path: @config_path,
            data_dir: data_dir,
            site_name: existing.site_name,
            email: existing.email,
            api_token: existing.api_token,
          )
          puts "Updated #{@config_path}"

          seed_aliases_file!(data_dir: data_dir)
          seed_project_names_file!(data_dir: data_dir)
          seed_approvals_file!(data_dir: data_dir)

          config = Claire::Config.load(path: @config_path)
          display_name = @jira_class.new(config).ping_myself
          puts "Authenticated as: #{display_name}"
          return
        end

        # Idempotent heal path (#38): config.yml AND data_dir both exist.
        # Re-load credentials from the local config (do NOT re-fetch from MCP —
        # that would clobber a healthy config if the MCP file has drifted).
        # Strip any phantom keys (e.g. legacy user.email from pre-#35), seed
        # any missing starter files, then ping JIRA to confirm auth.
        if File.exist?(@config_path)
          existing = Claire::Config.load(path: @config_path)
          Claire::Config.write!(
            path: @config_path,
            data_dir: data_dir,
            site_name: existing.site_name,
            email: existing.email,
            api_token: existing.api_token,
          )

          seed_aliases_file!(data_dir: data_dir)
          seed_project_names_file!(data_dir: data_dir)
          seed_approvals_file!(data_dir: data_dir)

          config = Claire::Config.load(path: @config_path)
          display_name = @jira_class.new(config).ping_myself
          puts "Authenticated as: #{display_name}"
          return
        end

        # Fresh init path: nothing exists yet.
        credentials = Claire::Config.from_mcp_json(path: @mcp_path)

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
        seed_project_names_file!(data_dir: data_dir)
        seed_approvals_file!(data_dir: data_dir)

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

      def seed_project_names_file!(data_dir:)
        path = File.join(data_dir, "project_names.yml")
        return if File.exist?(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, STARTER_PROJECT_NAMES)
        puts "Wrote #{path}"
      end

      def seed_approvals_file!(data_dir:)
        path = File.join(data_dir, "approvals.yml")
        return if File.exist?(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, STARTER_APPROVALS)
        puts "Wrote #{path}"
      end

      # Moves data files from the old config-dir layout into the new data dir.
      # For each filename: if the file exists in `from` but not in `to`, moves it.
      # Prints a header on first move and one line per moved file, with aligned arrows.
      # output: an IO object (defaults to $stdout)
      def self.migrate_legacy_data!(from:, to:, filenames:, output: $stdout)
        sources = filenames.map { |f| File.join(from, f) }
        destinations = filenames.map { |f| File.join(to, f) }

        pairs = sources.zip(destinations).select do |source, _|
          File.exist?(source)
        end

        return if pairs.empty?

        width = pairs.map { |source, _| source.length }.max
        output.puts "Migrating data files from legacy location:"
        pairs.each do |source, destination|
          if File.exist?(destination)
            backup = "#{destination}.bak"
            FileUtils.mv(destination, backup, force: true)
            output.puts "  backed up existing #{destination} -> #{backup}"
          end
          output.puts "  #{source.ljust(width)} -> #{destination}"
          FileUtils.mv(source, destination)
        end
      end
    end
  end
end
