# frozen_string_literal: true

require "date"
require "claire/report"
require "claire/project_names"

module Claire
  module CLI
    class Report
      DAY_NAMES = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

      def initialize(today: Date.today, project_names: Claire::ProjectNames)
        @today = today
        @project_names = project_names
      end

      def run(mode: :this_week, week: nil, start_date: nil, end_date: nil)
        grid = case mode
               when :this_week    then Claire::Report.weekly(week_containing: @today)
               when :last_week    then Claire::Report.weekly(week_containing: @today - 7)
               when :specific_week then Claire::Report.weekly(week_containing: week)
               when :range        then Claire::Report.range(start_date: start_date, end_date: end_date)
               end

        if grid.rows.empty?
          range_end = grid.start_date + grid.days.length - 1
          puts "no entries in this range (#{grid.start_date.iso8601} – #{range_end.iso8601})"
          return
        end

        puts format_grid(grid)
      rescue ArgumentError => e
        warn "claire report: #{e.message}"
        exit 1
      end

      private

      def format_grid(grid)
        day_headers = grid.days.map do |day|
          "#{DAY_NAMES[day.wday]} #{day.strftime("%m/%d")}"
        end

        all_headers = day_headers + ["TOTAL"]
        row_labels = grid.rows.keys.sort.map { |code| @project_names.label(code) }
        label_width = [(row_labels + ["TOTAL"]).map(&:length).max, 7].max
        col_widths = all_headers.map { |header| [header.length, 6].max }

        separator = build_separator(label_width, col_widths)
        header_row = build_header_row(all_headers, label_width, col_widths)

        lines = []
        lines << separator
        lines << header_row
        lines << separator

        grid.rows.sort.each_with_index do |(project_code, day_minutes), index|
          row_label = row_labels[index]
          row_total = day_minutes.sum
          cells = day_minutes.map { |minutes| Claire::Report.format_minutes(minutes) }
          cells << Claire::Report.format_minutes(row_total)
          lines << build_data_row(row_label, cells, label_width, col_widths)
        end

        lines << separator

        total_cells = grid.daily_totals.map { |minutes| Claire::Report.format_minutes(minutes) }
        total_cells << Claire::Report.format_minutes(grid.grand_total)
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
    end
  end
end
