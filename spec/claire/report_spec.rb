# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "date"
require "claire/report"
require "claire/config"

RSpec.describe Claire::Report do
  describe ".weekly" do
    it "returns an empty grid when the log file does not exist" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 13))

        expect(grid.rows).to be_empty
        expect(grid.daily_totals).to eq([0, 0, 0, 0, 0, 0, 0])
        expect(grid.grand_total).to eq(0)
      end
    end

    it "returns an empty grid when the log file exists but is empty" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 13))

        expect(grid.rows).to be_empty
        expect(grid.grand_total).to eq(0)
      end
    end

    it "sets start_date to the Sunday of the containing week" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")

        # 2026-05-14 is a Thursday; Sunday of that week is 2026-05-10
        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        expect(grid.start_date).to eq(Date.new(2026, 5, 10))
        expect(grid.days.length).to eq(7)
        expect(grid.days.first).to eq(Date.new(2026, 5, 10))
        expect(grid.days.last).to eq(Date.new(2026, 5, 16))
      end
    end

    it "includes a single entry in the current week in the correct day cell" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        # 2026-05-12 is Tuesday; week containing 2026-05-14 starts Sun 2026-05-10
        # Tuesday is index 2 in the week (Sun=0, Mon=1, Tue=2)
        File.write(path, JSON.generate({
          "id" => "abc",
          "created_at" => "2026-05-12T10:00:00Z",
          "worked_on" => "2026-05-12",
          "minutes" => 90,
          "project_code" => "PR00151",
          "jira_ticket" => nil,
          "pr_url" => nil,
          "note" => nil,
        }) + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        expect(grid.rows.keys).to eq(["PR00151"])
        row = grid.rows["PR00151"]
        expect(row[0]).to eq(0)   # Sun
        expect(row[1]).to eq(0)   # Mon
        expect(row[2]).to eq(90)  # Tue
        expect(row[3]).to eq(0)   # Wed
        expect(row[4]).to eq(0)   # Thu
        expect(row[5]).to eq(0)   # Fri
        expect(row[6]).to eq(0)   # Sat
        expect(grid.daily_totals[2]).to eq(90)
        expect(grid.grand_total).to eq(90)
      end
    end

    it "sums multiple entries for the same project on the same day" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "a1",
            "created_at" => "2026-05-12T09:00:00Z",
            "worked_on" => "2026-05-12",
            "minutes" => 30,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "a2",
            "created_at" => "2026-05-12T14:00:00Z",
            "worked_on" => "2026-05-12",
            "minutes" => 45,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        # Tuesday is index 2
        expect(grid.rows["PR00151"][2]).to eq(75)
        expect(grid.grand_total).to eq(75)
      end
    end

    it "distributes entries across multiple days into the correct cells" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "b1",
            "created_at" => "2026-05-11T09:00:00Z",
            "worked_on" => "2026-05-11",  # Monday, index 1
            "minutes" => 60,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "b2",
            "created_at" => "2026-05-14T09:00:00Z",
            "worked_on" => "2026-05-14",  # Thursday, index 4
            "minutes" => 120,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        row = grid.rows["PR00151"]
        expect(row[0]).to eq(0)    # Sun
        expect(row[1]).to eq(60)   # Mon
        expect(row[2]).to eq(0)    # Tue
        expect(row[3]).to eq(0)    # Wed
        expect(row[4]).to eq(120)  # Thu
        expect(row[5]).to eq(0)    # Fri
        expect(row[6]).to eq(0)    # Sat
        expect(grid.daily_totals[1]).to eq(60)
        expect(grid.daily_totals[4]).to eq(120)
        expect(grid.grand_total).to eq(180)
      end
    end

    it "tracks multiple projects separately with correct per-row and daily totals" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "c1",
            "created_at" => "2026-05-11T09:00:00Z",
            "worked_on" => "2026-05-11",  # Monday, index 1
            "minutes" => 60,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "c2",
            "created_at" => "2026-05-11T14:00:00Z",
            "worked_on" => "2026-05-11",  # Monday, index 1
            "minutes" => 45,
            "project_code" => "PR00188",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "c3",
            "created_at" => "2026-05-13T10:00:00Z",
            "worked_on" => "2026-05-13",  # Wednesday, index 3
            "minutes" => 90,
            "project_code" => "PR00188",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        expect(grid.rows.keys).to contain_exactly("PR00151", "PR00188")

        pr151_row = grid.rows["PR00151"]
        expect(pr151_row[1]).to eq(60)  # Mon
        expect(pr151_row.sum).to eq(60)

        pr188_row = grid.rows["PR00188"]
        expect(pr188_row[1]).to eq(45)  # Mon
        expect(pr188_row[3]).to eq(90)  # Wed
        expect(pr188_row.sum).to eq(135)

        expect(grid.daily_totals[1]).to eq(105)  # Mon: 60 + 45
        expect(grid.daily_totals[3]).to eq(90)   # Wed: 90
        expect(grid.grand_total).to eq(195)
      end
    end

    it "places a Saturday entry in the same week as the preceding Sunday (AC #7)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        # Saturday 2026-05-09 should be in the week starting Sun 2026-05-03
        File.write(path, JSON.generate({
          "id" => "d1",
          "created_at" => "2026-05-09T10:00:00Z",
          "worked_on" => "2026-05-09",
          "minutes" => 60,
          "project_code" => "PR00151",
          "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
        }) + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 9))

        expect(grid.start_date).to eq(Date.new(2026, 5, 3))
        # Saturday is index 6
        expect(grid.rows["PR00151"][6]).to eq(60)
        expect(grid.grand_total).to eq(60)
      end
    end

    it "places a Sunday entry in the same week as the following Saturday (AC #6)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        # Sunday 2026-05-10 starts a new week, ends Sat 2026-05-16
        File.write(path, JSON.generate({
          "id" => "e1",
          "created_at" => "2026-05-10T10:00:00Z",
          "worked_on" => "2026-05-10",
          "minutes" => 30,
          "project_code" => "PR00151",
          "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
        }) + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 10))

        expect(grid.start_date).to eq(Date.new(2026, 5, 10))
        expect(grid.days.last).to eq(Date.new(2026, 5, 16))
        # Sunday is index 0
        expect(grid.rows["PR00151"][0]).to eq(30)
        expect(grid.grand_total).to eq(30)
      end
    end

    it "excludes entries from outside the current week" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "f1",
            "created_at" => "2026-05-02T10:00:00Z",
            "worked_on" => "2026-05-02",  # last week (Sat 2026-05-02)
            "minutes" => 60,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "f2",
            "created_at" => "2026-05-14T10:00:00Z",
            "worked_on" => "2026-05-14",  # this week (Thu 2026-05-14)
            "minutes" => 90,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "f3",
            "created_at" => "2026-05-18T10:00:00Z",
            "worked_on" => "2026-05-18",  # next week (Mon 2026-05-18)
            "minutes" => 45,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        # Only the Thursday entry should be counted
        expect(grid.grand_total).to eq(90)
        # Thursday is index 4
        expect(grid.rows["PR00151"][4]).to eq(90)
      end
    end

    it "skips malformed JSONL lines without crashing and still counts valid rows" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        content = [
          JSON.generate({
            "id" => "g1",
            "created_at" => "2026-05-14T09:00:00Z",
            "worked_on" => "2026-05-14",
            "minutes" => 60,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          "NOT VALID JSON {{{",
          JSON.generate({
            "id" => "g2",
            "created_at" => "2026-05-14T14:00:00Z",
            "worked_on" => "2026-05-14",
            "minutes" => 30,
            "project_code" => "PR00151",
            "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, content.join("\n") + "\n")

        grid = nil
        expect {
          grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))
        }.not_to raise_error

        expect(grid.grand_total).to eq(90)
      end
    end

    it "grand_total equals the sum of daily_totals and the sum of all row totals (AC #5)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "h1", "created_at" => "2026-05-11T09:00:00Z",
            "worked_on" => "2026-05-11", "minutes" => 60,
            "project_code" => "PR00151", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "h2", "created_at" => "2026-05-13T09:00:00Z",
            "worked_on" => "2026-05-13", "minutes" => 45,
            "project_code" => "PR00188", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "h3", "created_at" => "2026-05-14T09:00:00Z",
            "worked_on" => "2026-05-14", "minutes" => 105,
            "project_code" => "PR00151", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        sum_of_daily_totals = grid.daily_totals.sum
        sum_of_row_totals = grid.rows.values.sum { |day_array| day_array.sum }

        expect(grid.grand_total).to eq(sum_of_daily_totals)
        expect(grid.grand_total).to eq(sum_of_row_totals)
        expect(grid.grand_total).to eq(210)
      end
    end

    it "produces exact decimal hours with integer-minute storage (AC #8)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        # 3 x 20 minutes = 60 minutes = exactly 1 hour
        lines = [
          JSON.generate({
            "id" => "i1", "created_at" => "2026-05-11T09:00:00Z",
            "worked_on" => "2026-05-11", "minutes" => 20,
            "project_code" => "PR00151", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "i2", "created_at" => "2026-05-11T10:00:00Z",
            "worked_on" => "2026-05-11", "minutes" => 20,
            "project_code" => "PR00151", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
          JSON.generate({
            "id" => "i3", "created_at" => "2026-05-11T11:00:00Z",
            "worked_on" => "2026-05-11", "minutes" => 20,
            "project_code" => "PR00151", "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))

        # Integer minutes are stored; conversion to hours happens at render time
        # 60 minutes = exactly 60, not floating point
        expect(grid.grand_total).to eq(60)
        expect(grid.rows["PR00151"][1]).to eq(60)  # Monday is index 1
        # 60 / 60.0 = exactly 1.0, not 0.999...
        expect(grid.grand_total / 60.0).to eq(1.0)
      end
    end

    it "warns with line number and snippet when a JSONL line is malformed" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "NOT VALID JSON {{{\n")

        expect {
          Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))
        }.to output(/claire report: skipping malformed JSONL line 1: NOT VALID JSON \{\{\{/).to_stderr
      end
    end

    it "warns with line number and snippet when worked_on is malformed" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, JSON.generate({
          "id" => "j1",
          "worked_on" => "not-a-date",
          "minutes" => 30,
          "project_code" => "PR00151",
        }) + "\n")

        expect {
          Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))
        }.to output(/claire report: skipping line 1 with malformed worked_on:/).to_stderr
      end
    end

    it "warns on malformed worked_on but still processes valid rows on other lines" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          JSON.generate({
            "id" => "k1",
            "worked_on" => "not-a-date",
            "minutes" => 30,
            "project_code" => "PR00151",
          }),
          JSON.generate({
            "id" => "k2",
            "worked_on" => "2026-05-14",
            "minutes" => 60,
            "project_code" => "PR00151",
          }),
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = nil
        expect {
          grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 14))
        }.to output(/malformed worked_on/).to_stderr

        expect(grid.grand_total).to eq(60)
      end
    end
  end

  describe ".range" do
    def entry(id:, worked_on:, minutes:, project_code:)
      JSON.generate({
        "id" => id,
        "created_at" => "#{worked_on}T09:00:00Z",
        "worked_on" => worked_on,
        "minutes" => minutes,
        "project_code" => project_code,
        "jira_ticket" => nil,
        "pr_url" => nil,
        "note" => nil,
      })
    end

    it "raises ArgumentError when end_date is before start_date" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        expect {
          Claire::Report.range(
            entries_path: path,
            start_date: Date.new(2026, 5, 8),
            end_date: Date.new(2026, 5, 4),
          )
        }.to raise_error(ArgumentError, /end_date must be >= start_date/)
      end
    end

    it "raises ArgumentError when the range is more than 14 days wide (15 days, end - start == 14)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        expect {
          Claire::Report.range(
            entries_path: path,
            start_date: Date.new(2026, 5, 1),
            end_date: Date.new(2026, 5, 15),
          )
        }.to raise_error(ArgumentError, /range too wide for table output; narrow it or skip it/)
      end
    end

    it "allows a 14-day range (end - start == 13)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        expect {
          Claire::Report.range(
            entries_path: path,
            start_date: Date.new(2026, 5, 1),
            end_date: Date.new(2026, 5, 14),
          )
        }.not_to raise_error
      end
    end

    it "returns a 1-column grid for a 1-day range" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, entry(id: "r1", worked_on: "2026-05-07", minutes: 60, project_code: "PR00151") + "\n")

        grid = Claire::Report.range(
          entries_path: path,
          start_date: Date.new(2026, 5, 7),
          end_date: Date.new(2026, 5, 7),
        )

        expect(grid.days.length).to eq(1)
        expect(grid.days.first).to eq(Date.new(2026, 5, 7))
        expect(grid.rows["PR00151"]).to eq([60])
        expect(grid.grand_total).to eq(60)
      end
    end

    it "returns a 14-column grid for a 14-day range" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        grid = Claire::Report.range(
          entries_path: path,
          start_date: Date.new(2026, 5, 1),
          end_date: Date.new(2026, 5, 14),
        )

        expect(grid.days.length).to eq(14)
        expect(grid.start_date).to eq(Date.new(2026, 5, 1))
      end
    end

    it "filters entries strictly between start_date and end_date inclusive" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        lines = [
          entry(id: "s1", worked_on: "2026-05-03", minutes: 30, project_code: "PR00151"),  # before range
          entry(id: "s2", worked_on: "2026-05-04", minutes: 60, project_code: "PR00151"),  # in range (start)
          entry(id: "s3", worked_on: "2026-05-06", minutes: 45, project_code: "PR00151"),  # in range
          entry(id: "s4", worked_on: "2026-05-08", minutes: 90, project_code: "PR00151"),  # in range (end)
          entry(id: "s5", worked_on: "2026-05-09", minutes: 20, project_code: "PR00151"),  # after range
        ]
        File.write(path, lines.join("\n") + "\n")

        grid = Claire::Report.range(
          entries_path: path,
          start_date: Date.new(2026, 5, 4),
          end_date: Date.new(2026, 5, 8),
        )

        # 5 days: May 4 (Mon), May 5 (Tue), May 6 (Wed), May 7 (Thu), May 8 (Fri)
        expect(grid.days.length).to eq(5)
        expect(grid.grand_total).to eq(195)  # 60 + 45 + 90
        row = grid.rows["PR00151"]
        expect(row[0]).to eq(60)  # May 4
        expect(row[1]).to eq(0)   # May 5
        expect(row[2]).to eq(45)  # May 6
        expect(row[3]).to eq(0)   # May 7
        expect(row[4]).to eq(90)  # May 8
      end
    end

    it "daily_totals length matches the number of days in the range" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        grid = Claire::Report.range(
          entries_path: path,
          start_date: Date.new(2026, 5, 4),
          end_date: Date.new(2026, 5, 8),
        )

        expect(grid.daily_totals.length).to eq(5)
      end
    end
  end

  describe ".weekly (regression — delegates to .range)" do
    it "still returns correct start_date and 7 days for a mid-week anchor" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, "")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 13))

        expect(grid.start_date).to eq(Date.new(2026, 5, 10))
        expect(grid.days.length).to eq(7)
        expect(grid.days.last).to eq(Date.new(2026, 5, 16))
      end
    end

    it "still produces correct grand_total after refactor" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        File.write(path, JSON.generate({
          "id" => "reg1",
          "created_at" => "2026-05-13T09:00:00Z",
          "worked_on" => "2026-05-13",
          "minutes" => 75,
          "project_code" => "PR00151",
          "jira_ticket" => nil, "pr_url" => nil, "note" => nil,
        }) + "\n")

        grid = Claire::Report.weekly(entries_path: path, week_containing: Date.new(2026, 5, 13))

        expect(grid.grand_total).to eq(75)
      end
    end
  end

  describe ".format_minutes" do
    it "formats 0 minutes as '0'" do
      expect(Claire::Report.format_minutes(0)).to eq("0")
    end

    it "formats 60 minutes as '1' (trailing zeros trimmed)" do
      expect(Claire::Report.format_minutes(60)).to eq("1")
    end

    it "formats 90 minutes as '1.5'" do
      expect(Claire::Report.format_minutes(90)).to eq("1.5")
    end

    it "formats 15 minutes as '0.25'" do
      expect(Claire::Report.format_minutes(15)).to eq("0.25")
    end

    it "formats 105 minutes as '1.75'" do
      expect(Claire::Report.format_minutes(105)).to eq("1.75")
    end

    it "formats 1 minute as '0.02' (non-zero rounds-to-zero preserved)" do
      expect(Claire::Report.format_minutes(1)).to eq("0.02")
    end

    it "formats 2 minutes as '0.03'" do
      expect(Claire::Report.format_minutes(2)).to eq("0.03")
    end

    it "formats 600 minutes as '10' (no leading-zero strip bug)" do
      expect(Claire::Report.format_minutes(600)).to eq("10")
    end

    it "formats 6000 minutes as '100'" do
      expect(Claire::Report.format_minutes(6000)).to eq("100")
    end

    it "formats 30 minutes as '0.5'" do
      expect(Claire::Report.format_minutes(30)).to eq("0.5")
    end
  end
end
