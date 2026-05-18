# frozen_string_literal: true

require "json"
require "date"
require "claire/config"

module Claire
  class Report
    Grid = Data.define(:start_date, :days, :rows, :daily_totals, :grand_total)
    # - start_date: Date (Sunday of the containing week)
    # - days: Array<Date> of length 7 (Sun..Sat)
    # - rows: { [project_code, epic_key] => [m_sun, ..., m_sat] }
    #         epic_key is nil for entries without one (raw project-code logs).
    # - daily_totals: [sum_sun, sum_mon, ..., sum_sat]  (integers, minutes)
    # - grand_total: integer minutes

    # Renders integer minutes as decimal hours per the display rules:
    # - 0 → "0"
    # - 60 → "1" (trailing zeros trimmed)
    # - 90 → "1.5"
    # - 1 → "0.02" (non-zero rounds-to-zero preserved)
    def self.format_minutes(minutes)
      ("%.2f" % (minutes / 60.0)).sub(/\.?0+\z/, "")
    end

    # @param entries_path [String] path to the JSONL file
    # @param week_containing [Date] anchor date; report shows the Sun–Sat week containing this date
    # @param grain [Symbol] :epic (default) or :ticket — see range()
    # @return [Grid] structured data ready for rendering
    def self.weekly(entries_path: Claire::Config.default_entries_path, week_containing: Date.today, grain: :epic)
      start_date = week_containing - week_containing.wday
      end_date = start_date + 6
      range(entries_path: entries_path, start_date: start_date, end_date: end_date, grain: grain)
    end

    # @param entries_path [String] path to the JSONL file
    # @param start_date [Date] first day of the range (inclusive)
    # @param end_date [Date] last day of the range (inclusive)
    # @param grain [Symbol] :epic groups by [project_code, epic_key];
    #                       :ticket groups by [project_code, epic_key, jira_ticket].
    # @return [Grid] structured data ready for rendering
    # @raise [ArgumentError] if end_date < start_date or range spans more than 14 days
    def self.range(entries_path: Claire::Config.default_entries_path, start_date:, end_date:, grain: :epic)
      raise ArgumentError, "end_date must be >= start_date" if end_date < start_date
      raise ArgumentError, "unknown grain: #{grain.inspect}" unless %i[epic ticket].include?(grain)

      days = (start_date..end_date).to_a
      raise ArgumentError, "range too wide for table output; narrow it or skip it" if days.length > 14

      minute_map = Hash.new { |hash, key| hash[key] = Hash.new(0) }

      if File.exist?(entries_path)
        File.foreach(entries_path).with_index(1) do |line, lineno|
          line = line.chomp
          next if line.strip.empty?

          begin
            parsed = JSON.parse(line)
          rescue JSON::ParserError
            warn "claire report: skipping malformed JSONL line #{lineno}: #{line.strip[0, 80]}"
            next
          end

          worked_on = begin
            Date.iso8601(parsed["worked_on"].to_s)
          rescue Date::Error, ArgumentError, TypeError
            warn "claire report: skipping line #{lineno} with malformed worked_on: #{line.strip[0, 80]}"
            next
          end

          next unless worked_on >= start_date && worked_on <= end_date

          project_code = parsed["project_code"].to_s
          next if project_code.empty?

          minutes = parsed["minutes"].to_i
          next unless minutes > 0

          epic_key = parsed["epic_key"]
          row_key =
            if grain == :ticket
              [project_code, epic_key, parsed["jira_ticket"]]
            else
              [project_code, epic_key]
            end
          minute_map[row_key][worked_on] += minutes
        end
      end

      rows = {}
      minute_map.each do |row_key, day_minutes|
        rows[row_key] = days.map { |day| day_minutes[day] }
      end

      daily_totals = (0...days.length).map do |day_index|
        rows.values.sum { |day_array| day_array[day_index] }
      end

      grand_total = daily_totals.sum

      Grid.new(
        start_date: start_date,
        days: days,
        rows: rows,
        daily_totals: daily_totals,
        grand_total: grand_total,
      )
    end
  end
end
