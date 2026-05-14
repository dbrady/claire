# frozen_string_literal: true

require "json"
require "date"
require "claire/config"

module Claire
  class Report
    Grid = Data.define(:start_date, :days, :rows, :daily_totals, :grand_total)
    # - start_date: Date (Sunday of the containing week)
    # - days: Array<Date> of length 7 (Sun..Sat)
    # - rows: { "PR00151" => [m_sun, m_mon, ..., m_sat] }  (integer minutes per day)
    # - daily_totals: [sum_sun, sum_mon, ..., sum_sat]  (integers, minutes)
    # - grand_total: integer minutes

    # @param entries_path [String] path to the JSONL file
    # @param week_containing [Date] anchor date; report shows the Sun–Sat week containing this date
    # @return [Grid] structured data ready for rendering
    def self.weekly(entries_path: Claire::Config.default_entries_path, week_containing: Date.today)
      start_date = week_containing - week_containing.wday
      days = (0..6).map { |offset| start_date + offset }
      end_date = start_date + 6

      minute_map = Hash.new { |hash, key| hash[key] = Hash.new(0) }

      if File.exist?(entries_path)
        File.foreach(entries_path) do |line|
          line = line.chomp
          next if line.strip.empty?

          begin
            parsed = JSON.parse(line)
          rescue JSON::ParserError
            warn "claire report: skipping malformed JSONL line"
            next
          end

          worked_on = begin
            Date.parse(parsed["worked_on"].to_s)
          rescue ArgumentError, TypeError
            next
          end

          next unless worked_on >= start_date && worked_on <= end_date

          project_code = parsed["project_code"].to_s
          next if project_code.empty?

          minutes = parsed["minutes"].to_i
          next unless minutes > 0

          minute_map[project_code][worked_on] += minutes
        end
      end

      rows = {}
      minute_map.each do |project_code, day_minutes|
        rows[project_code] = days.map { |day| day_minutes[day] }
      end

      daily_totals = (0..6).map do |day_index|
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
