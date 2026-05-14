# frozen_string_literal: true

require "date"

module Claire
  module Dates
    WEEKDAY_NAMES = {
      "mon" => 1,
      "tue" => 2,
      "wed" => 3,
      "thu" => 4,
      "fri" => 5,
      "sat" => 6,
      "sun" => 0,
    }.freeze

    # Parse a date string into a Date.
    #
    # Accepted forms:
    #   nil / ""          → today
    #   "today"           → today
    #   "yesterday"       → today - 1
    #   "mon".."sun"      → most recent occurrence (never future; today counts)
    #   "YYYY-MM-DD"      → that ISO date (strict pattern required)
    #   "M/D"             → that month/day in today's year
    #
    # Rejects ambiguous forms like "12-05" and anything else unparseable.
    #
    # @param input [String, nil]
    # @param today [Date] injectable for tests
    # @return [Date]
    # @raise [ArgumentError] on unparseable input
    def self.parse(input, today: Date.today)
      return today if input.nil? || input.strip.empty?

      normalized = input.strip.downcase

      return today if normalized == "today"
      return today - 1 if normalized == "yesterday"

      if WEEKDAY_NAMES.key?(normalized)
        target_wday = WEEKDAY_NAMES[normalized]
        days_back = (today.wday - target_wday) % 7
        return today - days_back
      end

      if normalized.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        begin
          return Date.strptime(normalized, "%Y-%m-%d")
        rescue Date::Error
          raise ArgumentError, "invalid date: #{input.inspect}"
        end
      end

      # US M/D format — 1 or 2 digits each, no leading zeros required
      if normalized.match?(/\A\d{1,2}\/\d{1,2}\z/)
        parts = normalized.split("/")
        month = parts[0].to_i
        day = parts[1].to_i
        begin
          return Date.new(today.year, month, day)
        rescue Date::Error
          raise ArgumentError, "invalid date: #{input.inspect}"
        end
      end

      raise ArgumentError, "unparseable date: #{input.inspect}"
    end
  end
end
