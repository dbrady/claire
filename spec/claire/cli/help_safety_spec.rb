# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require "fileutils"

# Pins the structural rule from #37: if `--help` (or `-h`) appears anywhere
# in the argv, NO side-effecting code path runs. Help printing and exit.
#
# This was a urgent bug — `claire init --help` previously fired the init
# code path, and only the legacy "refuse to overwrite" guard saved an
# existing config from being clobbered. That defense was structurally
# accidental; this spec turns it into a guarantee.
RSpec.describe "claire <subcommand> --help safety" do
  SUBCOMMANDS = %w[init doctor check log report edit alias approve].freeze

  let(:repo_root) { File.expand_path("../../..", __dir__) }

  def run_help(subcommand, env: {})
    Open3.capture3(
      { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile") }.merge(env),
      "bundle", "exec", File.join(repo_root, "bin", "claire"), subcommand, "--help",
      chdir: repo_root,
    )
  end

  SUBCOMMANDS.each do |subcommand|
    describe "claire #{subcommand} --help" do
      it "exits 0" do
        _stdout, _stderr, status = run_help(subcommand)
        expect(status.exitstatus).to eq(0)
      end

      it "writes a non-empty banner to stdout" do
        stdout, _stderr, _status = run_help(subcommand)
        # Optimist's auto-help banner includes a Usage: or Options: header.
        # We don't pin exact wording — only that something documentary was
        # printed. A subcommand that exits 0 with empty output is failing
        # the safety contract silently.
        expect(stdout).not_to be_empty
      end
    end
  end

  describe "claire init --help (the original bug — must not touch the filesystem)" do
    it "does not modify a pre-existing config.yml" do
      # Set up a sentinel config in a temp HOME. If `--help` triggers the
      # init code path, this file would be either rewritten or the run
      # would error out — both detectable.
      Dir.mktmpdir("claire-help-safety-spec") do |home|
        config_dir = File.join(home, ".config", "claire")
        FileUtils.mkdir_p(config_dir)
        config_path = File.join(config_dir, "config.yml")
        sentinel = "DO NOT REWRITE: sentinel for help-safety spec\n"
        File.write(config_path, sentinel)

        _stdout, _stderr, status = run_help("init", env: { "HOME" => home })

        expect(status.exitstatus).to eq(0)
        expect(File.read(config_path)).to eq(sentinel)
      end
    end
  end

  describe "claire doctor --help (idempotent twin of init — same safety)" do
    it "does not modify a pre-existing config.yml" do
      Dir.mktmpdir("claire-doctor-help-spec") do |home|
        config_dir = File.join(home, ".config", "claire")
        FileUtils.mkdir_p(config_dir)
        config_path = File.join(config_dir, "config.yml")
        sentinel = "DO NOT REWRITE: doctor sentinel\n"
        File.write(config_path, sentinel)

        _stdout, _stderr, status = run_help("doctor", env: { "HOME" => home })

        expect(status.exitstatus).to eq(0)
        expect(File.read(config_path)).to eq(sentinel)
      end
    end
  end
end
