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
        cache.put(pr_url: nil, jira_ticket: "MP-100", project_code: "PR00111")

        result = cache.get("MP-999")

        expect(result).to be_nil
      end
    end
  end

  describe "#put and #get" do
    it "round-trips an entry via the jira_ticket key" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: "https://github.com/org/repo/pull/42", jira_ticket: "MP-820", project_code: "PR00151")

        result = cache.get("MP-820")

        expect(result["pr_url"]).to eq("https://github.com/org/repo/pull/42")
        expect(result["jira_ticket"]).to eq("MP-820")
        expect(result["project_code"]).to eq("PR00151")
      end
    end

    it "round-trips an entry via the pr_url key" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: "https://github.com/org/repo/pull/42", jira_ticket: "MP-820", project_code: "PR00151")

        result = cache.get("https://github.com/org/repo/pull/42")

        expect(result["project_code"]).to eq("PR00151")
        expect(result["jira_ticket"]).to eq("MP-820")
      end
    end

    it "round-trips an entry via the project_code key" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: "https://github.com/org/repo/pull/42", jira_ticket: "MP-820", project_code: "PR00151")

        result = cache.get("PR00151")

        expect(result["project_code"]).to eq("PR00151")
        expect(result["jira_ticket"]).to eq("MP-820")
        expect(result["pr_url"]).to eq("https://github.com/org/repo/pull/42")
      end
    end

    it "finds a cross-direction entry: put with jira_ticket, get by project_code" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")

        result = cache.get("PR00151")

        expect(result["jira_ticket"]).to eq("MP-820")
        expect(result["project_code"]).to eq("PR00151")
      end
    end

    it "only writes keys for non-nil values" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "resolutions.yml")
        cache = Claire::Cache.new(path: path)
        cache.put(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")

        data = YAML.safe_load_file(path)

        expect(data.keys).to contain_exactly("MP-820", "PR00151")
        expect(data.keys).not_to include(nil.to_s)
      end
    end

    it "creates parent directories if they do not exist" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "deep", "nested", "resolutions.yml")
        cache = Claire::Cache.new(path: path)

        cache.put(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")

        expect(File.exist?(path)).to be true
      end
    end
  end

  describe "#delete_by_resolution" do
    it "removes all keys whose value shares the given project_code" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: "https://github.com/org/repo/pull/42", jira_ticket: "MP-820", project_code: "PR00151")

        cache.delete_by_resolution(pr_url: "https://github.com/org/repo/pull/42", jira_ticket: "MP-820", project_code: "PR00151")

        expect(cache.get("MP-820")).to be_nil
        expect(cache.get("PR00151")).to be_nil
        expect(cache.get("https://github.com/org/repo/pull/42")).to be_nil
      end
    end

    it "leaves entries for other project codes untouched" do
      Dir.mktmpdir do |dir|
        cache = Claire::Cache.new(path: File.join(dir, "resolutions.yml"))
        cache.put(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")
        cache.put(pr_url: nil, jira_ticket: "MP-999", project_code: "PR00999")

        cache.delete_by_resolution(pr_url: nil, jira_ticket: "MP-820", project_code: "PR00151")

        expect(cache.get("MP-820")).to be_nil
        expect(cache.get("MP-999")).not_to be_nil
        expect(cache.get("PR00999")).not_to be_nil
      end
    end
  end
end
