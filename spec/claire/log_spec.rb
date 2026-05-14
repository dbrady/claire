# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "date"
require "claire/log"
require "claire/config"

RSpec.describe Claire::Log do
  describe "#append" do
    it "writes a JSONL row with all 8 fields and reads it back correctly" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        log = Claire::Log.new(path: path)
        worked_on = Date.new(2026, 5, 12)

        log.append(
          project_code: "PR00151",
          minutes: 30,
          worked_on: worked_on,
          jira_ticket: "MP-820",
          pr_url: nil,
          note: "review of MP-796",
        )

        line = File.readlines(path).first.chomp
        row = JSON.parse(line)

        expect(row["project_code"]).to eq("PR00151")
        expect(row["minutes"]).to eq(30)
        expect(row["worked_on"]).to eq("2026-05-12")
        expect(row["jira_ticket"]).to eq("MP-820")
        expect(row["pr_url"]).to be_nil
        expect(row["note"]).to eq("review of MP-796")
        expect(row["id"]).to be_a(String)
        expect(row["id"]).not_to be_empty
        expect(row["created_at"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end

    it "appends multiple rows without overwriting previous entries" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        log = Claire::Log.new(path: path)
        worked_on = Date.new(2026, 5, 12)

        log.append(project_code: "PR00151", minutes: 30, worked_on: worked_on)
        log.append(project_code: "PR00222", minutes: 60, worked_on: worked_on)

        lines = File.readlines(path).map(&:chomp)
        expect(lines.length).to eq(2)

        first_row = JSON.parse(lines[0])
        second_row = JSON.parse(lines[1])
        expect(first_row["project_code"]).to eq("PR00151")
        expect(second_row["project_code"]).to eq("PR00222")
      end
    end

    it "creates parent directories if they do not exist" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "deep", "nested", "entries.jsonl")
        log = Claire::Log.new(path: path)

        log.append(project_code: "PR00151", minutes: 15, worked_on: Date.new(2026, 5, 12))

        expect(File.exist?(path)).to be true
      end
    end

    it "raises ArgumentError when project_code is nil" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        expect {
          log.append(project_code: nil, minutes: 30, worked_on: Date.new(2026, 5, 12))
        }.to raise_error(ArgumentError, /project_code required/)
      end
    end

    it "raises ArgumentError when project_code is empty string" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        expect {
          log.append(project_code: "", minutes: 30, worked_on: Date.new(2026, 5, 12))
        }.to raise_error(ArgumentError, /project_code required/)
      end
    end

    it "raises ArgumentError when minutes is not an integer" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        expect {
          log.append(project_code: "PR00151", minutes: 1.5, worked_on: Date.new(2026, 5, 12))
        }.to raise_error(ArgumentError, /positive integer/)
      end
    end

    it "raises ArgumentError when minutes is zero" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        expect {
          log.append(project_code: "PR00151", minutes: 0, worked_on: Date.new(2026, 5, 12))
        }.to raise_error(ArgumentError, /positive integer/)
      end
    end

    it "raises ArgumentError when minutes is negative" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        expect {
          log.append(project_code: "PR00151", minutes: -10, worked_on: Date.new(2026, 5, 12))
        }.to raise_error(ArgumentError, /positive integer/)
      end
    end

    it "sets a non-empty id on each row" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        log = Claire::Log.new(path: path)

        log.append(project_code: "PR00151", minutes: 15, worked_on: Date.new(2026, 5, 12))

        row = JSON.parse(File.readlines(path).first.chomp)
        expect(row["id"]).to be_a(String)
        expect(row["id"].length).to be > 10
      end
    end

    it "sets created_at to an ISO-8601 timestamp" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        log = Claire::Log.new(path: path)

        log.append(project_code: "PR00151", minutes: 15, worked_on: Date.new(2026, 5, 12))

        row = JSON.parse(File.readlines(path).first.chomp)
        expect(row["created_at"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end

    it "writes a row with only project_code when jira_ticket and pr_url are absent" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "entries.jsonl")
        log = Claire::Log.new(path: path)

        log.append(project_code: "PR00151", minutes: 15, worked_on: Date.new(2026, 5, 12))

        row = JSON.parse(File.readlines(path).first.chomp)
        expect(row["project_code"]).to eq("PR00151")
        expect(row["jira_ticket"]).to be_nil
        expect(row["pr_url"]).to be_nil
        expect(row["note"]).to be_nil
      end
    end

    it "returns the row hash from append" do
      Dir.mktmpdir do |dir|
        log = Claire::Log.new(path: File.join(dir, "entries.jsonl"))

        result = log.append(project_code: "PR00151", minutes: 30, worked_on: Date.new(2026, 5, 12))

        expect(result).to be_a(Hash)
        expect(result["project_code"]).to eq("PR00151")
        expect(result["minutes"]).to eq(30)
      end
    end
  end
end
