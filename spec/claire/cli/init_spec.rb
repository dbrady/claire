# frozen_string_literal: true

require "spec_helper"
require "claire/cli/init"
require "tmpdir"
require "stringio"

RSpec.describe Claire::CLI::Init do
  describe ".migrate_legacy_data!" do
    it "moves files that exist in the old location but not the new" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), '{"id":"1"}')

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl", "resolutions.yml"],
        output: output,
      )

      expect(File.exist?(File.join(new_dir, "entries.jsonl"))).to be(true)
      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq('{"id":"1"}')
      expect(File.exist?(File.join(old_dir, "entries.jsonl"))).to be(false)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "skips files that do not exist in the old location" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      # resolutions.yml does NOT exist in old_dir

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["resolutions.yml"],
        output: output,
      )

      expect(File.exist?(File.join(new_dir, "resolutions.yml"))).to be(false)
      expect(output.string).to eq("")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "does not overwrite a file that already exists in the new location" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "old content")
      File.write(File.join(new_dir, "entries.jsonl"), "new content")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("new content")
      expect(output.string).to eq("")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "prints a header on first move and one aligned line per moved file" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "data")
      File.write(File.join(old_dir, "resolutions.yml"), "cache")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl", "resolutions.yml"],
        output: output,
      )

      lines = output.string.lines
      expect(lines[0]).to match(/migrating data files from legacy location/i)
      expect(lines[1]).to include("entries.jsonl")
      expect(lines[2]).to include("resolutions.yml")
      expect(lines.length).to eq(3)

      # Both arrows must align — same column position on both data lines.
      arrow_positions = lines[1..2].map { |line| line.index(" -> ") }
      expect(arrow_positions.uniq.length).to eq(1), "arrows should be aligned"
    ensure
      FileUtils.remove_entry(dir)
    end

    it "prints nothing when no files need moving" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      # Nothing in old_dir

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl", "resolutions.yml"],
        output: output,
      )

      expect(output.string).to eq("")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "is a no-op (no moves, no output) when the new dir already exists with all files" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "old data")
      File.write(File.join(new_dir, "entries.jsonl"), "new data")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(output.string).to eq("")
      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("new data")
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
