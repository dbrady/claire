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

  describe ".expand_to_week (#50)" do
    let(:thursday) { Date.new(2026, 5, 14) } # Thursday; that week is Sun 5/10 .. Sat 5/16

    it "returns the Sun-Sat window containing today's week for 'this week'" do
      result = Claire::Dates.expand_to_week("this week", today: thursday)

      expect(result).to eq([Date.new(2026, 5, 10), Date.new(2026, 5, 16)])
    end

    it "returns the prior Sun-Sat window for 'last week'" do
      result = Claire::Dates.expand_to_week("last week", today: thursday)

      expect(result).to eq([Date.new(2026, 5, 3), Date.new(2026, 5, 9)])
    end

    it "returns the Sun-Sat window N weeks back for 'N weeks ago'" do
      result = Claire::Dates.expand_to_week("2 weeks ago", today: thursday)

      expect(result).to eq([Date.new(2026, 4, 26), Date.new(2026, 5, 2)])
    end

    it "handles 'three weeks ago' as English spelling" do
      result = Claire::Dates.expand_to_week("3 weeks ago", today: thursday)

      expect(result).to eq([Date.new(2026, 4, 19), Date.new(2026, 4, 25)])
    end

    it "expands an ISO date to its Sun-Sat week" do
      result = Claire::Dates.expand_to_week("2026-05-13", today: thursday)

      expect(result).to eq([Date.new(2026, 5, 10), Date.new(2026, 5, 16)])
    end

    it "expands a M/D date to its Sun-Sat week using today's year" do
      result = Claire::Dates.expand_to_week("5/13", today: thursday)

      expect(result).to eq([Date.new(2026, 5, 10), Date.new(2026, 5, 16)])
    end

    it "expands 'today' to today's week" do
      result = Claire::Dates.expand_to_week("today", today: thursday)

      expect(result).to eq([Date.new(2026, 5, 10), Date.new(2026, 5, 16)])
    end

    it "rejects 'next week' with a helpful ArgumentError" do
      expect {
        Claire::Dates.expand_to_week("next week", today: thursday)
      }.to raise_error(ArgumentError, /next week|unparseable|unrecognized/i)
    end

    it "rejects gibberish with ArgumentError" do
      expect {
        Claire::Dates.expand_to_week("hot dog", today: thursday)
      }.to raise_error(ArgumentError)
    end
  end
end
