# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "date"
require "claire/journal"
require "claire/config"

RSpec.describe Claire::Journal do
  def write_entries(dir, rows)
    path = File.join(dir, "entries.jsonl")
    lines = [{ "_schema" => "v2-epic-aware" }.to_json]
    lines.concat(rows.map { |r| r.to_json })
    File.write(path, lines.join("\n") + "\n")
    path
  end

  describe ".range" do
    it "returns one Entry per JSONL row whose worked_on falls in the range" do
      Dir.mktmpdir do |dir|
        path = write_entries(dir, [
          { "id" => "a", "created_at" => "2026-05-11T09:15:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151", "epic_key" => "MP-445", "jira_ticket" => "MP-715" },
          { "id" => "b", "created_at" => "2026-05-11T10:30:00-06:00", "worked_on" => "2026-05-11", "minutes" => 15, "project_code" => "PR00151", "epic_key" => "MP-445", "jira_ticket" => "MP-715" },
          { "id" => "c", "created_at" => "2026-05-05T08:00:00-06:00", "worked_on" => "2026-05-05", "minutes" => 60, "project_code" => "PR00151" }, # outside range
        ])

        entries = Claire::Journal.range(entries_path: path, start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 16))

        expect(entries.length).to eq(2)
        expect(entries.map(&:id)).to eq(["a", "b"])
      end
    end

    it "orders entries by created_at ascending" do
      Dir.mktmpdir do |dir|
        path = write_entries(dir, [
          { "id" => "later",  "created_at" => "2026-05-11T15:00:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151" },
          { "id" => "earlier","created_at" => "2026-05-11T09:00:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151" },
        ])

        entries = Claire::Journal.range(entries_path: path, start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 16))

        expect(entries.map(&:id)).to eq(["earlier", "later"])
      end
    end

    it "skips the schema marker line" do
      Dir.mktmpdir do |dir|
        path = write_entries(dir, [
          { "id" => "a", "created_at" => "2026-05-11T09:15:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151" },
        ])

        entries = Claire::Journal.range(entries_path: path, start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 16))

        # We get exactly one row, not two (schema marker has no worked_on).
        expect(entries.length).to eq(1)
      end
    end

    it "returns an empty list when the file does not exist" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "nonexistent.jsonl")

        expect(Claire::Journal.range(entries_path: path, start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 16))).to eq([])
      end
    end

    it "exposes fields the renderer needs: worked_on (Date), created_at (Time), ticket, epic, project, minutes" do
      Dir.mktmpdir do |dir|
        path = write_entries(dir, [
          { "id" => "a", "created_at" => "2026-05-11T09:15:00-06:00", "worked_on" => "2026-05-11", "minutes" => 30, "project_code" => "PR00151", "epic_key" => "MP-445", "jira_ticket" => "MP-715" },
        ])

        entry = Claire::Journal.range(entries_path: path, start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 16)).first

        expect(entry.worked_on).to eq(Date.new(2026, 5, 11))
        expect(entry.created_at).to be_a(Time)
        expect(entry.jira_ticket).to eq("MP-715")
        expect(entry.epic_key).to eq("MP-445")
        expect(entry.project_code).to eq("PR00151")
        expect(entry.minutes).to eq(30)
      end
    end
  end
end
