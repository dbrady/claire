# frozen_string_literal: true

require "spec_helper"
require "claire/duration"

RSpec.describe Claire::Duration do
  describe ".parse" do
    it "parses '0' as 0 minutes — but raises because 0 is not positive" do
      expect { Claire::Duration.parse("0") }.to raise_error(ArgumentError, /positive/)
    end

    it "treats bare integers, bare decimals, h-suffix, and m-suffix as equivalent forms of the same duration" do
      # 2 hours expressed four different ways must all collapse to 120 minutes.
      # The bare-integer case is the bug fix in #29: bare integers used to be
      # interpreted as minutes, which made '2' silently mean 1/60th of what
      # the user typed when they wrote 'claire log MP-830 2'.
      expect(Claire::Duration.parse("2")).to eq(120)
      expect(Claire::Duration.parse("2.0")).to eq(120)
      expect(Claire::Duration.parse("2h")).to eq(120)
      expect(Claire::Duration.parse("120m")).to eq(120)
    end

    it "parses '15' as 15 hours (900 minutes)" do
      result = Claire::Duration.parse("15")
      expect(result).to eq(900)
    end

    it "parses '60' as 60 hours (3600 minutes)" do
      result = Claire::Duration.parse("60")
      expect(result).to eq(3600)
    end

    it "parses '90' as 90 hours (5400 minutes)" do
      result = Claire::Duration.parse("90")
      expect(result).to eq(5400)
    end

    it "parses '1:30' as 90 minutes" do
      result = Claire::Duration.parse("1:30")
      expect(result).to eq(90)
    end

    it "parses '0:15' as 15 minutes" do
      result = Claire::Duration.parse("0:15")
      expect(result).to eq(15)
    end

    it "parses '1.5' as 90 minutes" do
      result = Claire::Duration.parse("1.5")
      expect(result).to eq(90)
    end

    it "parses '0.25' as 15 minutes" do
      result = Claire::Duration.parse("0.25")
      expect(result).to eq(15)
    end

    it "parses '2h' as 120 minutes" do
      result = Claire::Duration.parse("2h")
      expect(result).to eq(120)
    end

    it "parses '1.5h' as 90 minutes" do
      result = Claire::Duration.parse("1.5h")
      expect(result).to eq(90)
    end

    it "parses '90m' as 90 minutes" do
      result = Claire::Duration.parse("90m")
      expect(result).to eq(90)
    end

    it "parses '45m' as 45 minutes" do
      result = Claire::Duration.parse("45m")
      expect(result).to eq(45)
    end

    it "raises ArgumentError on 'abc'" do
      expect { Claire::Duration.parse("abc") }.to raise_error(ArgumentError, /unparseable/)
    end

    it "raises ArgumentError on '1:' (incomplete H:MM)" do
      expect { Claire::Duration.parse("1:") }.to raise_error(ArgumentError, /unparseable/)
    end

    it "raises ArgumentError on empty string" do
      expect { Claire::Duration.parse("") }.to raise_error(ArgumentError, /empty/)
    end

    it "raises ArgumentError on negative-like input '-5'" do
      expect { Claire::Duration.parse("-5") }.to raise_error(ArgumentError)
    end

    it "parses '30.5m' by rounding to 31 minutes" do
      result = Claire::Duration.parse("30.5m")
      expect(result).to eq(31)
    end

    it "parses '0.5m' by rounding up to 1 minute" do
      result = Claire::Duration.parse("0.5m")
      expect(result).to eq(1)
    end

    it "raises ArgumentError on '0.4m' because it rounds to 0 (not positive)" do
      expect { Claire::Duration.parse("0.4m") }.to raise_error(ArgumentError, /positive/)
    end
  end
end
