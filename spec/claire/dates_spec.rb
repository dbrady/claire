# frozen_string_literal: true

require "spec_helper"
require "date"
require "claire/dates"

RSpec.describe Claire::Dates do
  describe ".parse" do
    it "returns today when input is nil" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse(nil, today: today)

      expect(result).to eq(Date.new(2026, 5, 14))
    end

    it "returns today when input is empty string" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse("", today: today)

      expect(result).to eq(Date.new(2026, 5, 14))
    end

    it "returns today when input is 'today'" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse("today", today: today)

      expect(result).to eq(Date.new(2026, 5, 14))
    end

    it "returns yesterday when input is 'yesterday'" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse("yesterday", today: today)

      expect(result).to eq(Date.new(2026, 5, 13))
    end

    it "resolves 'mon' to most recent Monday when today is Wednesday" do
      today = Date.new(2026, 5, 13) # Wednesday

      result = Claire::Dates.parse("mon", today: today)

      expect(result).to eq(Date.new(2026, 5, 11)) # previous Monday
    end

    it "resolves 'wed' to today when today is Wednesday" do
      today = Date.new(2026, 5, 13) # Wednesday

      result = Claire::Dates.parse("wed", today: today)

      expect(result).to eq(Date.new(2026, 5, 13))
    end

    it "resolves 'thu' to the previous Thursday when today is Wednesday" do
      today = Date.new(2026, 5, 13) # Wednesday

      result = Claire::Dates.parse("thu", today: today)

      expect(result).to eq(Date.new(2026, 5, 7)) # never future
    end

    it "parses an ISO YYYY-MM-DD string" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse("2026-05-12", today: today)

      expect(result).to eq(Date.new(2026, 5, 12))
    end

    it "parses a US M/D string using today's year" do
      today = Date.new(2026, 5, 14)

      result = Claire::Dates.parse("5/12", today: today)

      expect(result).to eq(Date.new(2026, 5, 12))
    end

    it "raises ArgumentError for ambiguous '12-05' form" do
      expect { Claire::Dates.parse("12-05", today: Date.new(2026, 5, 14)) }.to raise_error(ArgumentError, /unparseable/)
    end

    it "raises ArgumentError for 'not-a-date'" do
      expect { Claire::Dates.parse("not-a-date", today: Date.new(2026, 5, 14)) }.to raise_error(ArgumentError, /unparseable/)
    end

    it "raises ArgumentError for YYYY/MM/DD (slash-separated ISO)" do
      expect { Claire::Dates.parse("2026/05/12", today: Date.new(2026, 5, 14)) }.to raise_error(ArgumentError, /unparseable/)
    end

    it "accepts weekday names case-insensitively" do
      today = Date.new(2026, 5, 13) # Wednesday

      result = Claire::Dates.parse("MON", today: today)

      expect(result).to eq(Date.new(2026, 5, 11))
    end
  end
end
