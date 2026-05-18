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

      def run(mode: :this_week, week: nil, start_date: nil, end_date: nil, names: false, full: false)
        grain = full ? :ticket : :epic
        grid = case mode
               when :this_week    then Claire::Report.weekly(week_containing: @today, grain: grain)
               when :last_week    then Claire::Report.weekly(week_containing: @today - 7, grain: grain)
               when :specific_week then Claire::Report.weekly(week_containing: week, grain: grain)
               when :range        then Claire::Report.range(start_date: start_date, end_date: end_date, grain: grain)
               end

        if grid.rows.empty?
          range_end = grid.start_date + grid.days.length - 1
          puts "no entries in this range (#{grid.start_date.iso8601} – #{range_end.iso8601})"
          return
        end

        puts format_grid(grid, names: names, full: full)
      rescue ArgumentError => e
        warn "claire report: #{e.message}"
        exit 1
      end

      private

      def format_grid(grid, names:, full:)
        day_headers = grid.days.map do |day|
          "#{DAY_NAMES[day.wday]} #{day.strftime("%m/%d")}"
        end

        all_headers = day_headers + ["TOTAL"]

        # Sort by the full row key, coercing nil components to "" so the
        # comparator doesn't blow up on (str <=> nil).
        sorted_rows = grid.rows.sort_by { |key, _| key.map(&:to_s) }

        project_labels = sorted_rows.map { |key, _| names ? @project_names.label(key[0]) : key[0] }
        epic_labels    = sorted_rows.map { |key, _| key[1] || "-" }
        ticket_labels  = full ? sorted_rows.map { |key, _| key[2] || "-" } : nil

        label_headers = ["Project", "Epic"]
        label_widths  = [
          [(project_labels + ["Project"]).map(&:length).max, 7].max,
          [(epic_labels    + ["Epic"]).map(&:length).max, 6].max,
        ]
        all_label_columns = [project_labels, epic_labels]

        if full
          label_headers << "Ticket"
          label_widths  << [(ticket_labels + ["Ticket"]).map(&:length).max, 6].max
          all_label_columns << ticket_labels
        end

        col_widths = all_headers.map { |header| [header.length, 6].max }

        separator = build_separator(label_widths, col_widths)
        header_row = build_header_row(label_headers, label_widths, all_headers, col_widths)

        lines = []
        lines << separator
        lines << header_row
        lines << separator

        sorted_rows.each_with_index do |(_key, day_minutes), index|
          row_total = day_minutes.sum
          cells = day_minutes.map { |minutes| Claire::Report.format_minutes(minutes) }
          cells << Claire::Report.format_minutes(row_total)
          labels = all_label_columns.map { |col| col[index] }
          lines << build_data_row(labels, cells, label_widths, col_widths)
        end

        lines << separator

        total_cells = grid.daily_totals.map { |minutes| Claire::Report.format_minutes(minutes) }
        total_cells << Claire::Report.format_minutes(grid.grand_total)
        total_labels = ["TOTAL"] + Array.new(label_widths.length - 1, "")
        lines << build_data_row(total_labels, total_cells, label_widths, col_widths)
        lines << separator

        lines.join("\n")
      end

      def build_separator(label_widths, col_widths)
        parts = label_widths.map { |w| "-" * (w + 2) }
        col_widths.each { |width| parts << "-" * (width + 2) }
        "+#{parts.join("+")}+"
      end

      def build_header_row(label_headers, label_widths, headers, col_widths)
        label_cells = label_headers.each_with_index.map do |text, i|
          " " + text.ljust(label_widths[i]) + " "
        end
        day_cells = headers.each_with_index.map do |header, index|
          " " + header.center(col_widths[index]) + " "
        end
        "|#{label_cells.join("|")}|#{day_cells.join("|")}|"
      end

      def build_data_row(labels, cells, label_widths, col_widths)
        label_cells = labels.each_with_index.map do |text, i|
          " " + text.to_s.ljust(label_widths[i]) + " "
        end
        value_cells = cells.each_with_index.map do |value, index|
          " " + value.rjust(col_widths[index]) + " "
        end
        "|#{label_cells.join("|")}|#{value_cells.join("|")}|"
      end
    end
  end
end
