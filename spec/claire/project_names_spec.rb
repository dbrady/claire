# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "claire/project_names"

RSpec.describe Claire::ProjectNames do
  describe ".lookup" do
    it "returns the name when the code is defined in the YAML file" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")

      result = Claire::ProjectNames.lookup("PR00632", path: path)

      expect(result).to eq("Black Friday Remediation")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil when the code is not in the YAML file" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")

      result = Claire::ProjectNames.lookup("PR99999", path: path)

      expect(result).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil when the file does not exist" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")

      result = Claire::ProjectNames.lookup("PR00632", path: path)

      expect(result).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil when the file is empty" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "")

      result = Claire::ProjectNames.lookup("PR00632", path: path)

      expect(result).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".label" do
    it "returns 'code - name' when the name is defined" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")

      result = Claire::ProjectNames.label("PR00632", path: path)

      expect(result).to eq("PR00632 - Black Friday Remediation")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns just the code when the name is not defined" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")

      result = Claire::ProjectNames.label("PR99999", path: path)

      expect(result).to eq("PR99999")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns just the code when the name is an empty string" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: \"\"\n")

      result = Claire::ProjectNames.label("PR00632", path: path)

      expect(result).to eq("PR00632")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns just the code when the file does not exist" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")

      result = Claire::ProjectNames.label("PR00632", path: path)

      expect(result).to eq("PR00632")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns the full label when total length is exactly 50 characters (boundary)" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      # "PR00632 - " is 10 chars; name must be 40 chars to hit exactly 50
      name = "A" * 40
      File.write(path, "PR00632: #{name}\n")

      result = Claire::ProjectNames.label("PR00632", path: path, max_width: 50)

      expect(result.length).to eq(50)
      expect(result).to eq("PR00632 - #{name}")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "truncates with ellipsis when total length is 51 characters (just over boundary)" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      # "PR00632 - " is 10 chars; name is 41 chars → total 51 chars, must truncate
      name = "A" * 41
      File.write(path, "PR00632: #{name}\n")

      result = Claire::ProjectNames.label("PR00632", path: path, max_width: 50)

      expect(result.length).to eq(50)
      expect(result).to end_with("…")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "truncates a long name to max_width with trailing ellipsis" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      long_name = "Customer-Facing Notification System Rewrite Phase 3 Migration"
      File.write(path, "PR00632: #{long_name}\n")

      result = Claire::ProjectNames.label("PR00632", path: path)

      expect(result.length).to eq(50)
      expect(result).to start_with("PR00632 - Customer-Facing Notification System Rew")
      expect(result).to end_with("…")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "respects a custom max_width kwarg" do
      dir = Dir.mktmpdir
      path = File.join(dir, "project_names.yml")
      File.write(path, "PR00632: Black Friday Remediation\n")

      result = Claire::ProjectNames.label("PR00632", path: path, max_width: 20)

      expect(result.length).to eq(20)
      expect(result).to end_with("…")
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
