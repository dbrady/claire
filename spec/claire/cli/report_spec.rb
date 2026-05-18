# frozen_string_literal: true

require "spec_helper"
require "claire/cli/report"
require "claire/config"
require "tmpdir"

# Pins #36: project names are OFF by default in claire report. Row labels are
# bare project codes. `--names` (wired in bin/claire as `names: true`) opts in
# to the enriched "CODE - Name" form. The previous default (always show names)
# made the table wider and harder to scan for the common case where the user
# already knows their codes.
RSpec.describe Claire::CLI::Report do
  let(:thursday) { Date.new(2026, 5, 14) } # mid-week, well inside any Sun-Sat span

  def with_data_dir
    Dir.mktmpdir("claire-report-cli-spec") do |dir|
      entries_path = File.join(dir, "entries.jsonl")
      File.write(entries_path, [
        { project_code: "PR00673", minutes: 60, worked_on: "2026-05-14" }.to_json,
        { project_code: "PR00425", minutes: 120, worked_on: "2026-05-14" }.to_json,
      ].join("\n") + "\n")

      project_names_path = File.join(dir, "project_names.yml")
      File.write(project_names_path, YAML.dump(
        "PR00673" => "Backend Foo",
        "PR00425" => "Frontend Bar",
      ))

      allow(Claire::Config).to receive(:default_entries_path).and_return(entries_path)
      allow(Claire::Config).to receive(:default_project_names_path).and_return(project_names_path)
      yield
    end
  end

  it "shows Project and Epic header columns (#49)" do
    with_data_dir do
      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }

      header_line = output.lines.find { |l| l.include?("Project") && l.include?("Epic") }
      expect(header_line).not_to be_nil, "expected a header row with Project and Epic columns; got:\n#{output}"
    end
  end

  it "shows separate rows for two epics that share a project code (#49)" do
    Dir.mktmpdir("claire-report-cli-two-epics") do |dir|
      entries_path = File.join(dir, "entries.jsonl")
      File.write(entries_path, [
        { project_code: "PR00151", epic_key: "MP-445", minutes: 60,  worked_on: "2026-05-14" }.to_json,
        { project_code: "PR00151", epic_key: "MP-777", minutes: 120, worked_on: "2026-05-14" }.to_json,
      ].join("\n") + "\n")

      project_names_path = File.join(dir, "project_names.yml")
      File.write(project_names_path, YAML.dump({}))

      allow(Claire::Config).to receive(:default_entries_path).and_return(entries_path)
      allow(Claire::Config).to receive(:default_project_names_path).and_return(project_names_path)

      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }

      mp445_line = output.lines.find { |l| l.include?("MP-445") }
      mp777_line = output.lines.find { |l| l.include?("MP-777") }
      expect(mp445_line).not_to be_nil
      expect(mp777_line).not_to be_nil
      expect(mp445_line).to include("PR00151")
      expect(mp777_line).to include("PR00151")
    end
  end

  it "renders bare project codes by default (no name lookup)" do
    with_data_dir do
      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }

      expect(output).to include("PR00673")
      expect(output).to include("PR00425")
      # Default mode should NOT enrich with names — the bare-codes contract.
      expect(output).not_to include("Backend Foo")
      expect(output).not_to include("Frontend Bar")
    end
  end

  it "renders enriched 'CODE - Name' row labels when names: true" do
    with_data_dir do
      output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week, names: true) }

      expect(output).to include("PR00673 - Backend Foo")
      expect(output).to include("PR00425 - Frontend Bar")
    end
  end

  it "renders an unregistered project code as a bare code in both modes" do
    Dir.mktmpdir("claire-report-cli-unregistered") do |dir|
      entries_path = File.join(dir, "entries.jsonl")
      File.write(entries_path, { project_code: "PRUNKNOWN", minutes: 30, worked_on: "2026-05-14" }.to_json + "\n")

      project_names_path = File.join(dir, "project_names.yml")
      File.write(project_names_path, YAML.dump({}))

      allow(Claire::Config).to receive(:default_entries_path).and_return(entries_path)
      allow(Claire::Config).to receive(:default_project_names_path).and_return(project_names_path)

      default_output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week) }
      named_output = capture_stdout { described_class.new(today: thursday).run(mode: :this_week, names: true) }

      expect(default_output).to include("PRUNKNOWN")
      expect(named_output).to include("PRUNKNOWN")
      # No spurious " - " separator when the name is missing — bare code only.
      expect(named_output).not_to match(/PRUNKNOWN\s*-\s*\S/)
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
