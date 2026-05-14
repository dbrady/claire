# frozen_string_literal: true

require "spec_helper"
require "claire/cli/init"
require "tmpdir"
require "stringio"

RSpec.describe Claire::CLI::Init do
  describe "#seed_project_names_file!" do
    it "writes the starter project_names.yml with an example entry" do
      dir = Dir.mktmpdir
      init = described_class.new

      init.send(:seed_project_names_file!, data_dir: dir)

      path = File.join(dir, "project_names.yml")
      expect(File.exist?(path)).to be(true)
      content = File.read(path)
      expect(content).to include("PREXAMPLE: Example project name")
      expect(content).to include("claire log, check, and report")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "does not overwrite an existing project_names.yml" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")
      init = described_class.new

      init.send(:seed_project_names_file!, data_dir: dir)

      expect(File.read(path)).to eq("PR00632: Black Friday Remediation\n")
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#seed_approvals_file!" do
    it "writes the starter approvals.yml with the PREXAMPLE entry" do
      dir = Dir.mktmpdir
      init = described_class.new

      init.send(:seed_approvals_file!, data_dir: dir)

      path = File.join(dir, "approvals.yml")
      expect(File.exist?(path)).to be(true)
      content = File.read(path)
      expect(content).to include("PREXAMPLE")
      expect(content).to include("claire approve")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "does not overwrite an existing approvals.yml" do
      dir = Dir.mktmpdir
      path = File.join(dir, "approvals.yml")
      File.write(path, "PR00673: \"2026-05-14T08:32:50-06:00\"\n")
      init = described_class.new

      init.send(:seed_approvals_file!, data_dir: dir)

      expect(File.read(path)).to eq("PR00673: \"2026-05-14T08:32:50-06:00\"\n")
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#seed_aliases_file!" do
    it "writes the starter aliases.yml with an example entry" do
      dir = Dir.mktmpdir
      init = described_class.new

      init.send(:seed_aliases_file!, data_dir: dir)

      path = File.join(dir, "aliases.yml")
      expect(File.exist?(path)).to be(true)
      content = File.read(path)
      expect(content).to include("EXAMPLE: PR00000")
      expect(content).to include("claire alias add")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "does not overwrite an existing aliases.yml" do
      dir = Dir.mktmpdir
      path = File.join(dir, "aliases.yml")
      File.write(path, "BF: PR00673\n")
      init = described_class.new

      init.send(:seed_aliases_file!, data_dir: dir)

      expect(File.read(path)).to eq("BF: PR00673\n")
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#run" do
    context "legacy upgrade path: config.yml exists in config dir, no data dir yet" do
      it "migrates entries.jsonl to the data dir and updates config with data_dir" do
        dir = Dir.mktmpdir("claire-legacy-spec")
        config_dir = File.join(dir, ".config", "claire")
        data_dir = File.join(dir, ".local", "share", "claire")
        FileUtils.mkdir_p(config_dir)

        config_path = File.join(config_dir, "config.yml")
        File.write(config_path, <<~YAML)
          ---
          atlassian:
            site_name: acme
            email: alice@acme.com
            api_token: secret
          user:
            email: alice@acme.com
        YAML
        entries_old = File.join(config_dir, "entries.jsonl")
        File.write(entries_old, "{\"id\":\"1\"}\n")
        resolutions_old = File.join(config_dir, "resolutions.yml")
        File.write(resolutions_old, "---\n{}\n")

        fake_jira = class_double(Claire::Jira)
        fake_jira_instance = instance_double(Claire::Jira, ping_myself: "Alice")
        allow(fake_jira).to receive(:new).and_return(fake_jira_instance)

        init = described_class.new(
          config_path: config_path,
          jira_class: fake_jira,
        )

        # Intercept the XDG data dir so migration targets our tmpdir
        allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

        expect { init.run }.not_to raise_error

        expect(File.exist?(File.join(data_dir, "entries.jsonl"))).to be(true)
        expect(File.read(File.join(data_dir, "entries.jsonl"))).to eq("{\"id\":\"1\"}\n")
        expect(File.exist?(entries_old)).to be(false)

        expect(File.exist?(File.join(data_dir, "resolutions.yml"))).to be(true)
        expect(File.exist?(resolutions_old)).to be(false)

        config = Claire::Config.load(path: config_path)
        expect(config.data_dir).to eq(data_dir)
      ensure
        FileUtils.remove_entry(dir)
      end

      it "does not refuse with 'config already exists' — exits 0" do
        dir = Dir.mktmpdir("claire-legacy-spec")
        config_dir = File.join(dir, ".config", "claire")
        data_dir = File.join(dir, ".local", "share", "claire")
        FileUtils.mkdir_p(config_dir)

        config_path = File.join(config_dir, "config.yml")
        File.write(config_path, <<~YAML)
          ---
          atlassian:
            site_name: acme
            email: alice@acme.com
            api_token: secret
          user:
            email: alice@acme.com
        YAML

        fake_jira = class_double(Claire::Jira)
        fake_jira_instance = instance_double(Claire::Jira, ping_myself: "Alice")
        allow(fake_jira).to receive(:new).and_return(fake_jira_instance)

        init = described_class.new(
          config_path: config_path,
          jira_class: fake_jira,
        )

        allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

        expect { init.run }.not_to raise_error
      ensure
        FileUtils.remove_entry(dir)
      end

      it "seeds approvals.yml in the data dir" do
        dir = Dir.mktmpdir("claire-legacy-spec")
        config_dir = File.join(dir, ".config", "claire")
        data_dir = File.join(dir, ".local", "share", "claire")
        FileUtils.mkdir_p(config_dir)

        config_path = File.join(config_dir, "config.yml")
        File.write(config_path, <<~YAML)
          ---
          atlassian:
            site_name: acme
            email: alice@acme.com
            api_token: secret
          user:
            email: alice@acme.com
        YAML

        fake_jira = class_double(Claire::Jira)
        fake_jira_instance = instance_double(Claire::Jira, ping_myself: "Alice")
        allow(fake_jira).to receive(:new).and_return(fake_jira_instance)

        init = described_class.new(
          config_path: config_path,
          jira_class: fake_jira,
        )

        allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

        init.run

        approvals_path = File.join(data_dir, "approvals.yml")
        expect(File.exist?(approvals_path)).to be(true)
        expect(File.read(approvals_path)).to include("PREXAMPLE")
      ensure
        FileUtils.remove_entry(dir)
      end
    end

    context "modern install: config.yml AND data_dir both exist" do
      it "refuses with exit 1" do
        dir = Dir.mktmpdir("claire-modern-spec")
        config_dir = File.join(dir, ".config", "claire")
        data_dir = File.join(dir, ".local", "share", "claire")
        FileUtils.mkdir_p(config_dir)
        FileUtils.mkdir_p(data_dir)

        config_path = File.join(config_dir, "config.yml")
        File.write(config_path, "existing config\n")

        init = described_class.new(config_path: config_path)

        allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

        expect { init.run }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      ensure
        FileUtils.remove_entry(dir)
      end
    end
  end

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

    it "backs up the destination and replaces it with the legacy source when both files exist" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy content")
      File.write(File.join(new_dir, "entries.jsonl"), "existing destination content")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy content")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("existing destination content")
      expect(File.exist?(File.join(old_dir, "entries.jsonl"))).to be(false)
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

    it "prints the backup line before the move line when there is a conflict" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy content")
      File.write(File.join(new_dir, "entries.jsonl"), "existing content")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      lines = output.string.lines
      backup_line_index = lines.index { |l| l.include?("backed up existing") }
      move_line_index = lines.rindex { |l| l.include?("entries.jsonl") && !l.include?("backed up") }
      expect(backup_line_index).not_to be_nil
      expect(move_line_index).not_to be_nil
      expect(backup_line_index).to be < move_line_index
    ensure
      FileUtils.remove_entry(dir)
    end

    it "backs up both files when both destinations already exist (multi-file conflict)" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy entries")
      File.write(File.join(new_dir, "entries.jsonl"), "existing entries")
      File.write(File.join(old_dir, "resolutions.yml"), "legacy resolutions")
      File.write(File.join(new_dir, "resolutions.yml"), "existing resolutions")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl", "resolutions.yml"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy entries")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("existing entries")
      expect(File.read(File.join(new_dir, "resolutions.yml"))).to eq("legacy resolutions")
      expect(File.read(File.join(new_dir, "resolutions.yml.bak"))).to eq("existing resolutions")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "backs up only the conflicting file when only one of two destinations exists" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy entries")
      File.write(File.join(new_dir, "entries.jsonl"), "existing entries")
      File.write(File.join(old_dir, "resolutions.yml"), "legacy resolutions")
      # resolutions.yml does NOT exist in new_dir

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl", "resolutions.yml"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy entries")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("existing entries")
      expect(File.read(File.join(new_dir, "resolutions.yml"))).to eq("legacy resolutions")
      expect(File.exist?(File.join(new_dir, "resolutions.yml.bak"))).to be(false)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "overwrites a pre-existing .bak file silently when re-running migration" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy content")
      File.write(File.join(new_dir, "entries.jsonl"), "current destination content")
      File.write(File.join(new_dir, "entries.jsonl.bak"), "old bak from prior run")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy content")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("current destination content")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "creates a backup even when destination is empty" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy content")
      File.write(File.join(new_dir, "entries.jsonl"), "")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy content")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "migrates and backs up when the new dir already exists with all files" do
      dir = Dir.mktmpdir
      old_dir = File.join(dir, "old")
      new_dir = File.join(dir, "new")
      FileUtils.mkdir_p(old_dir)
      FileUtils.mkdir_p(new_dir)
      File.write(File.join(old_dir, "entries.jsonl"), "legacy data")
      File.write(File.join(new_dir, "entries.jsonl"), "existing data")

      output = StringIO.new
      described_class.migrate_legacy_data!(
        from: old_dir,
        to: new_dir,
        filenames: ["entries.jsonl"],
        output: output,
      )

      expect(File.read(File.join(new_dir, "entries.jsonl"))).to eq("legacy data")
      expect(File.read(File.join(new_dir, "entries.jsonl.bak"))).to eq("existing data")
      expect(output.string).to include("backed up existing")
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
