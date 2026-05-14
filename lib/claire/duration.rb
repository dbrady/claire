# frozen_string_literal: true

module Claire
  module Duration
    # Parse a duration string into integer minutes.
    #
    # Accepted forms:
    #   "15"    → 15 minutes (bare integer)
    #   "1:30"  → 90 minutes (H:MM)
    #   "1.5"   → 90 minutes (decimal hours)
    #   "0.25"  → 15 minutes (decimal hours)
    #   "90m"   → 90 minutes (N minutes suffix)
    #   "2h"    → 120 minutes (N hours suffix)
    #   "1.5h"  → 90 minutes (decimal hours suffix)
    #
    # Order of detection: suffix (m/h) → H:MM → decimal → bare integer
    #
    # @param input [String]
    # @return [Integer] minutes
    # @raise [ArgumentError] on unparseable input
    def self.parse(input)
      raise ArgumentError, "duration cannot be empty" if input.nil? || input.strip.empty?

      str = input.strip

      # Suffix: Nm or Nh (including decimal hours like 1.5h)
      if str.match?(/\A(\d+(?:\.\d+)?)[mh]\z/i)
        number = str[0..-2].to_f
        suffix = str[-1].downcase
        if suffix == "m"
          minutes = number.round
          raise ArgumentError, "minutes must be positive: #{input}" if minutes <= 0
          return minutes
        else
          minutes = (number * 60).round
          raise ArgumentError, "hours must be positive: #{input}" if minutes <= 0
          return minutes
        end
      end

      # H:MM format
      if str.match?(/\A\d+:\d{2}\z/)
        hours_part, minutes_part = str.split(":").map(&:to_i)
        total = hours_part * 60 + minutes_part
        raise ArgumentError, "duration must be positive: #{input}" if total <= 0
        return total
      end

      # Decimal (must have a dot)
      if str.match?(/\A\d+\.\d+\z/)
        minutes = (str.to_f * 60).round
        raise ArgumentError, "hours must be positive: #{input}" if minutes <= 0
        return minutes
      end

      # Bare integer → minutes
      if str.match?(/\A\d+\z/)
        minutes = str.to_i
        raise ArgumentError, "minutes must be positive: #{input}" if minutes <= 0
        return minutes
      end

      raise ArgumentError, "unparseable duration: #{input.inspect}"
    end
  end
end
