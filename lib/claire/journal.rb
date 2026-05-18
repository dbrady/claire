# frozen_string_literal: true

require "json"
require "date"
require "time"
require "claire/config"

module Claire
  class Journal
    Entry = Data.define(
      :id,
      :created_at,
      :worked_on,
      :minutes,
      :project_code,
      :epic_key,
      :jira_ticket,
      :pr_url,
      :note,
    )

    # Read entries.jsonl, return a chronological list of Entry instances whose
    # worked_on falls in [start_date, end_date]. Skips the schema marker line
    # (it has no worked_on) and malformed rows.
    def self.range(entries_path: Claire::Config.default_entries_path, start_date:, end_date:)
      raise ArgumentError, "end_date must be >= start_date" if end_date < start_date
      return [] unless File.exist?(entries_path)

      entries = []
      File.foreach(entries_path).with_index(1) do |line, lineno|
        stripped = line.chomp
        next if stripped.empty?

        begin
          row = JSON.parse(stripped)
        rescue JSON::ParserError
          warn "claire journal: skipping malformed JSONL line #{lineno}"
          next
        end

        next if row.key?("_schema") # schema marker line
        worked_on_str = row["worked_on"]
        next if worked_on_str.nil? || worked_on_str.to_s.empty?

        begin
          worked_on = Date.iso8601(worked_on_str.to_s)
        rescue Date::Error, ArgumentError
          warn "claire journal: skipping line #{lineno} with malformed worked_on"
          next
        end

        next unless worked_on >= start_date && worked_on <= end_date

        created_at = begin
          Time.iso8601(row["created_at"].to_s)
        rescue ArgumentError
          Time.at(0)
        end

        entries << Entry.new(
          id: row["id"],
          created_at: created_at,
          worked_on: worked_on,
          minutes: row["minutes"].to_i,
          project_code: row["project_code"],
          epic_key: row["epic_key"],
          jira_ticket: row["jira_ticket"],
          pr_url: row["pr_url"],
          note: row["note"],
        )
      end

      # Primary sort by worked_on so the table reads chronologically by when
      # the work happened, not when it was logged. Stable secondary by
      # created_at preserves intra-day order.
      entries.sort_by { |e| [e.worked_on, e.created_at] }
    end

    def self.weekly(entries_path: Claire::Config.default_entries_path, week_containing: Date.today)
      sunday = week_containing - week_containing.wday
      range(entries_path: entries_path, start_date: sunday, end_date: sunday + 6)
    end
  end
end
