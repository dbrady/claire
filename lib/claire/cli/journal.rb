# frozen_string_literal: true

require "date"
require "claire/journal"
require "claire/report"

module Claire
  module CLI
    class Journal
      HEADERS = ["Date", "Time", "Ticket", "Epic", "Project", "Hours"].freeze

      def initialize(today: Date.today)
        @today = today
      end

      # mode: :this_week (default), :last_week, :specific_week, :range
      def run(mode: :this_week, week: nil, start_date: nil, end_date: nil)
        entries = case mode
                  when :this_week    then Claire::Journal.weekly(week_containing: @today)
                  when :last_week    then Claire::Journal.weekly(week_containing: @today - 7)
                  when :specific_week then Claire::Journal.weekly(week_containing: week)
                  when :range        then Claire::Journal.range(start_date: start_date, end_date: end_date)
                  end

        if entries.empty?
          puts "no entries in this range"
          return
        end

        puts format_table(entries)
      rescue ArgumentError => e
        warn "claire journal: #{e.message}"
        exit 1
      end

      private

      def format_table(entries)
        rows = entries.map { |e| row_for(e) }
        widths = HEADERS.each_with_index.map do |header, i|
          [(rows.map { |r| r[i].length } + [header.length]).max, 6].max
        end

        separator = "+#{widths.map { |w| "-" * (w + 2) }.join("+")}+"
        header_cells = HEADERS.each_with_index.map { |h, i| " " + h.ljust(widths[i]) + " " }
        header_line = "|#{header_cells.join("|")}|"

        lines = [separator, header_line, separator]
        rows.each do |cells|
          rendered = cells.each_with_index.map { |c, i| " " + c.ljust(widths[i]) + " " }
          lines << "|#{rendered.join("|")}|"
        end
        lines << separator
        lines.join("\n")
      end

      def row_for(entry)
        [
          entry.worked_on.iso8601,
          entry.created_at.strftime("%H:%M"),
          entry.jira_ticket || "-",
          entry.epic_key || "-",
          entry.project_code,
          Claire::Report.format_minutes(entry.minutes),
        ]
      end
    end
  end
end
