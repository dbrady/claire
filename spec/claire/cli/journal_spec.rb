# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "date"
require "stringio"
require "claire/cli/journal"
require "claire/config"

RSpec.describe Claire::CLI::Journal do
  let(:thursday) { Date.new(2026, 5, 14) }

  def write_entries(dir, rows)
    path = File.join(dir, "entries.jsonl")
    lines = [{ "_schema" => "v2-epic-aware" }.to_json]
    lines.concat(rows.map { |r| r.to_json })
    File.write(path, lines.join("\n") + "\n")
    path
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  it "renders one row per logged entry with Date, Time, Ticket, Epic, Project, Hours columns" do
    Dir.mktmpdir do |dir|
      path = write_entries(dir, [
        { "id" => "a", "created_at" => "2026-05-11T09:15:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151", "epic_key" => "MP-445", "jira_ticket" => "MP-715" },
        { "id" => "b", "created_at" => "2026-05-11T15:30:00-06:00", "worked_on" => "2026-05-11", "minutes" => 15, "project_code" => "PR00151", "epic_key" => "MP-445", "jira_ticket" => "MP-715" },
      ])
      allow(Claire::Config).to receive(:default_entries_path).and_return(path)

      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }

      header = output.lines.find { |l| l.include?("Date") && l.include?("Time") && l.include?("Hours") }
      expect(header).not_to be_nil, "expected header with Date, Time, Hours; got:\n#{output}"
      expect(header).to include("Ticket")
      expect(header).to include("Epic")
      expect(header).to include("Project")
      # Two distinct rows, not aggregated.
      data_rows = output.lines.select { |l| l.include?("MP-715") }
      expect(data_rows.length).to eq(2)
      expect(output).to include("09:15")
      expect(output).to include("15:30")
    end
  end

  it "tells the user when no entries fall in the range" do
    Dir.mktmpdir do |dir|
      path = write_entries(dir, [])
      allow(Claire::Config).to receive(:default_entries_path).and_return(path)

      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }

      expect(output).to match(/no entries/i)
    end
  end
end
