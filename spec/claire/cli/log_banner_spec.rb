# frozen_string_literal: true

require "spec_helper"
require "open3"

# Pins the contents of `claire log --help` so future option-block refactors
# can't silently drop the usage banner. We assert *what the user must see*,
# not the exact wording — each check probes one example form per axis
# (target, duration, date) so the banner stays useful as documentation.
RSpec.describe "claire log --help banner" do
  let(:help_output) do
    repo_root = File.expand_path("../../..", __dir__)
    stdout, _stderr, status = Open3.capture3(
      { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile") },
      "bundle", "exec", File.join(repo_root, "bin", "claire"), "log", "--help",
      chdir: repo_root,
    )
    raise "claire log --help exited #{status.exitstatus}: #{stdout}" unless status.success?
    stdout
  end

  describe "synopsis" do
    it "shows the positional argument order" do
      expect(help_output).to match(/claire log\s+<target>\s+<duration>/)
    end
  end

  describe "target forms" do
    it "documents PR numbers" do
      expect(help_output).to include("17347")
    end

    it "documents PR URLs" do
      expect(help_output).to include("https://github.com/")
    end

    it "documents JIRA tickets" do
      expect(help_output).to include("MP-830")
    end

    it "documents JIRA URLs" do
      expect(help_output).to include("atlassian.net")
    end

    it "documents project codes" do
      expect(help_output).to include("PR00673")
    end
  end

  describe "duration forms" do
    it "shows that a bare integer means hours" do
      expect(help_output).to match(/\b2\b.*hour/i)
    end

    it "shows the h suffix" do
      expect(help_output).to include("2h")
    end

    it "shows the m suffix" do
      expect(help_output).to include("120m")
    end

    it "shows that 2, 2h, and 120m are equivalent" do
      expect(help_output).to match(/2\b.*=.*2h.*=.*120m|equivalent/i)
    end
  end

  describe "date forms (--on)" do
    it "shows --on today" do
      expect(help_output).to match(/--on\s+today/i)
    end

    it "shows --on yesterday" do
      expect(help_output).to include("yesterday")
    end

    it "shows a weekday form" do
      expect(help_output).to match(/--on\s+(mon|tue|wed|thu|fri|sat|sun)/i)
    end

    it "shows the M/D form" do
      expect(help_output).to match(/--on\s+\d{1,2}\/\d{1,2}/)
    end

    it "shows the ISO date form" do
      expect(help_output).to match(/--on\s+\d{4}-\d{2}-\d{2}/)
    end
  end
end
