# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "claire/cli/check"
require "claire/resolver"

RSpec.describe Claire::CLI::Check do
  def hop(key, summary:, issuetype:)
    { "key" => key, "summary" => summary, "issuetype" => issuetype }
  end

  def resolution(walked_chain:, project_code:, epic_key:, pr_url: nil)
    Claire::Resolver::Resolution.new(
      pr_url: pr_url,
      jira_ticket: walked_chain.first&.fetch("key"),
      walked_chain: walked_chain,
      project_code: project_code,
      epic_key: epic_key,
    )
  end

  def resolver_returning(res)
    fake = Class.new do
      def initialize(res) = @res = res
      def resolve(_input, refresh: false) = @res
    end.new(res)
  end

  def clipboard_noop
    Class.new do
      def copy(_text) = false
      def paste_shortcut = nil
    end.new
  end

  def approvals_returning(stamp)
    fake = Class.new do
      def initialize(stamp) = @stamp = stamp
      def lookup(_) = @stamp
    end.new(stamp)
  end

  def project_names_passthrough
    Class.new do
      def label(code) = code
    end.new
  end

  def run_check(res, approval: nil)
    check = Claire::CLI::Check.new(
      resolver: resolver_returning(res),
      clipboard: clipboard_noop,
      project_names: project_names_passthrough,
      approvals: approvals_returning(approval),
    )
    out = StringIO.new
    $stdout = out
    check.run("ignored-input")
    out.string
  ensure
    $stdout = STDOUT
  end

  describe "#run nested tree output (#46)" do
    it "renders one indented line per walked hop with KEY: (IssueType) Summary" do
      res = resolution(
        walked_chain: [
          hop("MP-715", summary: "Convert decorators", issuetype: "Sub-Task"),
          hop("MP-421", summary: "es-MX date presentation", issuetype: "Story"),
          hop("MP-445", summary: "MX2 - MP Additional Adjustments", issuetype: "Epic"),
        ],
        project_code: "PR00151",
        epic_key: "MP-445",
      )

      out = run_check(res)

      lines = out.lines.map(&:rstrip)
      expect(lines).to include("MP-715: (Sub-Task) Convert decorators")
      expect(lines).to include("  -> MP-421: (Story) es-MX date presentation")
      expect(lines).to include("    -> MP-445: (Epic) MX2 - MP Additional Adjustments")
      expect(lines).to include("      -> PR00151: PR00151")
    end

    it "looks up approvals by epic_key, not project_code (the [OK] line mentions the epic)" do
      # Use distinct values so the assertion can tell which one is on the
      # approval line vs which one is on the tree/project line.
      res = resolution(
        walked_chain: [hop("MP-445", summary: "Epic", issuetype: "Epic")],
        project_code: "PR00151",
        epic_key: "MP-445",
      )

      out = run_check(res, approval: "2026-05-14T08:32:50-06:00")

      approval_line = out.lines.find { |l| l.include?("[OK]") }
      expect(approval_line).not_to be_nil, "expected an [OK] approval line in: #{out.inspect}"
      expect(approval_line).to include("MP-445")
      expect(approval_line).not_to include("PR00151")
      expect(approval_line).to include("2026-05-14")
    end

    it "names the epic on the manual-mode line when no approval is recorded" do
      res = resolution(
        walked_chain: [hop("MP-999", summary: "Other epic", issuetype: "Epic")],
        project_code: "PR00151",
        epic_key: "MP-999",
      )

      out = run_check(res, approval: nil)

      manual_line = out.lines.find { |l| l.include?("manual mode") }
      expect(manual_line).not_to be_nil
      expect(manual_line).to include("MP-999")
      expect(manual_line).not_to include("PR00151")
    end

    it "renders only the project code line when there is no walk" do
      res = resolution(walked_chain: [], project_code: "PR00151", epic_key: nil)

      out = run_check(res)

      lines = out.lines.map(&:rstrip)
      expect(lines).to include("PR00151: PR00151")
      expect(lines).not_to include(a_string_matching(/->/))
    end
  end
end
