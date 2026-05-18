# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"
require "time"
require "date"
require "claire/config"

module Claire
  class Log
    # Bump when the on-disk row shape changes. Alpha product: old files
    # are wiped on first append, not migrated.
    SCHEMA_VERSION = "v2-epic-aware"
    SCHEMA_MARKER = { "_schema" => SCHEMA_VERSION }.freeze

    def initialize(path: Claire::Config.default_entries_path)
      @path = path
    end

    # Append one JSONL row to the log file.
    #
    # @param project_code [String] required; never nil
    # @param minutes [Integer] required; must be positive
    # @param worked_on [Date] required; the date the work was done
    # @param jira_ticket [String, nil] JIRA key, e.g. "MP-820"
    # @param epic_key [String, nil] JIRA key of the epic this work rolls up to (Clarity's unit of approval)
    # @param pr_url [String, nil] GitHub PR URL
    # @param note [String, nil] free-text note
    # @return [Hash] the row that was written
    def append(project_code:, minutes:, worked_on:, jira_ticket: nil, epic_key: nil, pr_url: nil, note: nil)
      raise ArgumentError, "project_code required" if project_code.nil? || project_code.to_s.strip.empty?
      raise ArgumentError, "minutes must be a positive integer" unless minutes.is_a?(Integer) && minutes > 0

      row = {
        "id"           => generate_id,
        "created_at"   => Time.now.iso8601,
        "worked_on"    => worked_on.iso8601,
        "minutes"      => minutes,
        "project_code" => project_code,
        "jira_ticket"  => jira_ticket,
        "epic_key"     => epic_key,
        "pr_url"       => pr_url,
        "note"         => note,
      }

      FileUtils.mkdir_p(File.dirname(@path))
      ensure_schema_marker

      File.open(@path, "a") do |file|
        file.flock(File::LOCK_EX)
        file.puts(JSON.generate(row))
        file.flock(File::LOCK_UN)
      end

      row
    end

    private

    # If the file is missing or its first line isn't the current schema marker,
    # truncate it and write the marker. Old logs (pre-#47) lack the epic_key
    # field; rather than backfilling, we drop them — alpha product.
    def ensure_schema_marker
      first_line = File.exist?(@path) ? File.open(@path, &:gets) : nil
      return if first_line && JSON.parse(first_line) == SCHEMA_MARKER
      File.open(@path, "w") do |file|
        file.flock(File::LOCK_EX)
        file.puts(JSON.generate(SCHEMA_MARKER))
        file.flock(File::LOCK_UN)
      end
    rescue JSON::ParserError
      File.open(@path, "w") do |file|
        file.flock(File::LOCK_EX)
        file.puts(JSON.generate(SCHEMA_MARKER))
        file.flock(File::LOCK_UN)
      end
    end

    # UUIDv7 is sortable by timestamp, satisfying the spirit of the ULID requirement.
    # SecureRandom.uuid_v7 is available in Ruby 3.3+; fall back to uuid (v4) otherwise.
    def generate_id
      if SecureRandom.respond_to?(:uuid_v7)
        SecureRandom.uuid_v7
      else
        SecureRandom.uuid
      end
    end
  end
end
