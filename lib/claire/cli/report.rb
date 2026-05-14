# frozen_string_literal: true

require "date"
require "claire/report"

module Claire
  module CLI
    class Report
      DAY_NAMES = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

      def initialize(today: Date.today)
        @today = today
      end

      def run
        grid = Claire::Report.weekly(week_containing: @today)

        if grid.rows.empty?
          puts "no entries this week (#{grid.start_date.iso8601} – #{(grid.start_date + 6).iso8601})"
          return
        end

        puts format_grid(grid)
      end

      private

      def format_grid(grid)
        day_headers = grid.days.map.with_index do |day, index|
          "#{DAY_NAMES[index]} #{day.strftime("%m/%d")}"
        end

        all_headers = day_headers + ["TOTAL"]
        label_width = [grid.rows.keys.map(&:length).max, 7].max
        col_widths = all_headers.map { |header| [header.length, 6].max }

        separator = build_separator(label_width, col_widths)
        header_row = build_header_row(all_headers, label_width, col_widths)

        lines = []
        lines << separator
        lines << header_row
        lines << separator

        grid.rows.sort.each do |project_code, day_minutes|
          row_total = day_minutes.sum
          cells = day_minutes.map { |minutes| format_minutes(minutes) }
          cells << format_minutes(row_total)
          lines << build_data_row(project_code, cells, label_width, col_widths)
        end

        lines << separator

        total_cells = grid.daily_totals.map { |minutes| format_minutes(minutes) }
        total_cells << format_minutes(grid.grand_total)
        lines << build_data_row("TOTAL", total_cells, label_width, col_widths)
        lines << separator

        lines.join("\n")
      end

      def build_separator(label_width, col_widths)
        parts = ["-" * (label_width + 2)]
        col_widths.each { |width| parts << "-" * (width + 2) }
        "+#{parts.join("+")}+"
      end

      def build_header_row(headers, label_width, col_widths)
        label_cell = " " + "".ljust(label_width) + " "
        day_cells = headers.each_with_index.map do |header, index|
          " " + header.center(col_widths[index]) + " "
        end
        "|#{label_cell}|#{day_cells.join("|")}|"
      end

      def build_data_row(label, cells, label_width, col_widths)
        label_cell = " " + label.ljust(label_width) + " "
        value_cells = cells.each_with_index.map do |value, index|
          " " + value.rjust(col_widths[index]) + " "
        end
        "|#{label_cell}|#{value_cells.join("|")}|"
      end

      def format_minutes(minutes)
        ("%.2f" % (minutes / 60.0)).sub(/\.?0+\z/, "")
      end
    end
  end
end
