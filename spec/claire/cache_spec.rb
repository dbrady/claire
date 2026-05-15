# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "claire/cache"

RSpec.describe Claire::Cache do
  describe "#get" do
    it "returns nil when the cache file does not exist" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "nonexistent.yml"))

        result = cache.get("MP-820")

        expect(result).to be_nil
      end
    end

    it "returns nil when the key is not in the cache" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "resolutions.yml")
        cache = Claire::Cache.new(path: path)
        cache.put(key: "MP-100", jira_ticket: "MP-100", project_code: "PR00111", walked_chain: [])

        result = cache.get("MP-999")

        expect(result).to be_nil
      end
    end
  end

  describe "#put and #get" do
    it "round-trips an entry written under the jira-ticket key" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(
          key: "MP-820",
          pr_url: "https://github.com/org/repo/pull/42",
          jira_ticket: "MP-820",
          project_code: "PR00151",
          walked_chain: [],
        )

        result = cache.get("MP-820")

        expect(result["pr_url"]).to eq("https://github.com/org/repo/pull/42")
        expect(result["jira_ticket"]).to eq("MP-820")
        expect(result["project_code"]).to eq("PR00151")
        expect(result["walked_chain"]).to eq([])
      end
    end

    it "round-trips an entry written under the project-code key with the stripped shape" do
      # Project-code entries carry only the project code — no jira_ticket, no
      # pr_url — because many tickets resolve to the same code and choosing
      # one to keep would flap as different walks write the same key.
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(
          key: "PR00151",
          pr_url: nil,
          jira_ticket: nil,
          project_code: "PR00151",
          walked_chain: [],
        )

        result = cache.get("PR00151")

        expect(result["project_code"]).to eq("PR00151")
        expect(result["jira_ticket"]).to be_nil
        expect(result["pr_url"]).to be_nil
        expect(result["walked_chain"]).to eq([])
      end
    end

    it "preserves a multi-step walked_chain through the YAML round-trip" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(
          key: "MP-796",
          pr_url: nil,
          jira_ticket: "MP-796",
          project_code: "PR00151",
          walked_chain: ["MP-445"],
        )

        result = cache.get("MP-796")

        expect(result["walked_chain"]).to eq(["MP-445"])
      end
    end

    it "defaults walked_chain to an empty array when omitted" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(key: "MP-820", jira_ticket: "MP-820", project_code: "PR00151")

        result = cache.get("MP-820")

        expect(result["walked_chain"]).to eq([])
      end
    end

    it "writes only the requested key (no fan-out to pr_url or project_code)" do
      # Previous behaviour fanned the same entry out under every non-nil
      # identifier. That made per-key shapes impossible (the project-code
      # entry inherited whichever jira_ticket wrote it last). The new
      # contract is one put = one key.
      Dir.mktmpdir do |dir|
        path = File.join(dir, "resolutions.yml")
        cache = Claire::Cache.new(path: path)
        cache.put(
          key: "MP-820",
          pr_url: "https://github.com/org/repo/pull/42",
          jira_ticket: "MP-820",
          project_code: "PR00151",
        )

        data = YAML.safe_load_file(path)

        expect(data.keys).to contain_exactly("MP-820")
      end
    end

    it "creates parent directories if they do not exist" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "deep", "nested", "resolutions.yml")
        cache = Claire::Cache.new(path: path)

        cache.put(key: "MP-820", jira_ticket: "MP-820", project_code: "PR00151")

        expect(File.exist?(path)).to be true
      end
    end
  end

  describe "#delete_by_resolution" do
    it "removes every key whose entry shares the given project_code" do
      # Verifies the cascade: callers (resolver on refresh) write a family of
      # entries that all share a project_code, and a single delete must wipe
      # the whole family regardless of how it was indexed.
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        # Three entries for the same resolution — what the resolver writes for
        # a PR-input walk MP-820 carrying project code PR00151.
        cache.put(
          key: "https://github.com/org/repo/pull/42",
          pr_url: "https://github.com/org/repo/pull/42",
          jira_ticket: "MP-820",
          project_code: "PR00151",
        )
        cache.put(
          key: "MP-820",
          pr_url: "https://github.com/org/repo/pull/42",
          jira_ticket: "MP-820",
          project_code: "PR00151",
        )
        cache.put(key: "PR00151", project_code: "PR00151")

        cache.delete_by_resolution(
          pr_url: "https://github.com/org/repo/pull/42",
          jira_ticket: "MP-820",
          project_code: "PR00151",
        )

        expect(cache.get("MP-820")).to be_nil
        expect(cache.get("PR00151")).to be_nil
        expect(cache.get("https://github.com/org/repo/pull/42")).to be_nil
      end
    end

    it "leaves entries for other project codes untouched" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(key: "MP-820", jira_ticket: "MP-820", project_code: "PR00151")
        cache.put(key: "PR00151", project_code: "PR00151")
        cache.put(key: "MP-999", jira_ticket: "MP-999", project_code: "PR00999")
        cache.put(key: "PR00999", project_code: "PR00999")

        cache.delete_by_resolution(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")

        expect(cache.get("MP-820")).to be_nil
        expect(cache.get("PR00151")).to be_nil
        expect(cache.get("MP-999")).not_to be_nil
        expect(cache.get("PR00999")).not_to be_nil
      end
    end
  end
end
