# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "stringio"
require "date"
require "json"
require "claire/cli/log"
require "claire/config"

# Unit spec for the CLI plumbing layer (Claire::CLI::Log). Drives a fake
# resolver, lets the real Claire::Log write to a tmpdir, and inspects the
# resulting JSONL plus the captured banner.
RSpec.describe Claire::CLI::Log do
  def resolver_returning(resolution)
    Class.new do
      def initialize(res) = @res = res
      def resolve(_target, refresh: false, config: nil) = @res
    end.new(resolution)
  end

  def project_names_passthrough
    Class.new do
      def label(code) = code
    end.new
  end

  def resolution(project_code:, jira_ticket:, epic_key:, pr_url: nil, walked_chain: [])
    Claire::Resolver::Resolution.new(
      pr_url: pr_url,
      jira_ticket: jira_ticket,
      walked_chain: walked_chain,
      project_code: project_code,
      epic_key: epic_key,
    )
  end

  def with_tmp_entries
    Dir.mktmpdir do |dir|
      path = File.join(dir, "entries.jsonl")
      config = Class.new do
        def initialize(p) = @p = p
        attr_reader :p
      end.new(path)
      allow(Claire::Config).to receive(:default_entries_path).with(config: config).and_return(path)
      yield path, config
    end
  end

  def capture_stdout
    out = StringIO.new
    orig = $stdout
    $stdout = out
    yield
    out.string
  ensure
    $stdout = orig
  end

  describe "#run (#47)" do
    it "persists epic_key from the resolution onto the JSONL row" do
      res = resolution(project_code: "PR00151", jira_ticket: "MP-820", epic_key: "MP-445")

      with_tmp_entries do |path, config|
        cli = Claire::CLI::Log.new(
          resolver_class: resolver_returning(res),
          config: config,
          today: Date.new(2026, 5, 14),
          project_names: project_names_passthrough,
        )
        capture_stdout { cli.run("MP-820", "30m") }

        rows = File.readlines(path).map { |l| JSON.parse(l.chomp) }.reject { |r| r.key?("_schema") }
        expect(rows.last["epic_key"]).to eq("MP-445")
      end
    end

    it "includes the epic key in the banner when present" do
      res = resolution(project_code: "PR00151", jira_ticket: "MP-820", epic_key: "MP-445")

      with_tmp_entries do |_path, config|
        cli = Claire::CLI::Log.new(
          resolver_class: resolver_returning(res),
          config: config,
          today: Date.new(2026, 5, 14),
          project_names: project_names_passthrough,
        )

        banner = capture_stdout { cli.run("MP-820", "30m") }
        expect(banner).to include("MP-445")
        expect(banner).to include("MP-820")
        expect(banner).to include("PR00151")
      end
    end
  end
end
