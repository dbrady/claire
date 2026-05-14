# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "claire/target"
require "claire/approvals"

RSpec.describe Claire::Approvals do
  def make_approvals(dir)
    path = File.join(dir, "approvals.yml")
    described_class.new(path: path)
  end

  describe "#record and #lookup" do
    it "writes the approval so that lookup returns the iso8601 timestamp" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)
      timestamp = Time.new(2026, 5, 14, 8, 32, 50, "-06:00")

      store.record("PR00673", timestamp: timestamp)

      result = store.lookup("PR00673")
      expect(result).to eq(timestamp.iso8601)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil (previous value) when recording a brand-new approval" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      previous = store.record("PR00673")

      expect(previous).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "overwrites an existing approval and returns the previous timestamp string" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)
      first_time = Time.new(2026, 5, 14, 8, 0, 0, "-06:00")
      second_time = Time.new(2026, 5, 15, 9, 0, 0, "-06:00")
      store.record("PR00673", timestamp: first_time)

      previous = store.record("PR00673", timestamp: second_time)

      expect(previous).to eq(first_time.iso8601)
      expect(store.lookup("PR00673")).to eq(second_time.iso8601)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "accepts a plain project code like PR00673" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect { store.record("PR00673") }.not_to raise_error
    ensure
      FileUtils.remove_entry(dir)
    end

    it "accepts an opaque project code that looks like a strange string" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect { store.record("TSK-X-Y") }.not_to raise_error
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#lookup" do
    it "returns nil when the file does not exist" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect(store.lookup("PR00673")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil when the key is not in the file" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)
      store.record("PR99999")

      expect(store.lookup("PR00673")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#list" do
    it "returns an alphabetical hash of all approvals" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)
      store.record("PR00003", timestamp: Time.new(2026, 5, 10, 0, 0, 0, "+00:00"))
      store.record("PR00001", timestamp: Time.new(2026, 5, 11, 0, 0, 0, "+00:00"))
      store.record("PR00002", timestamp: Time.new(2026, 5, 12, 0, 0, 0, "+00:00"))

      result = store.list

      expect(result.keys).to eq(["PR00001", "PR00002", "PR00003"])
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns an empty hash when the file does not exist" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect(store.list).to eq({})
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#rm" do
    it "removes the entry so that subsequent lookup returns nil" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)
      store.record("PR00673")

      store.rm("PR00673")

      expect(store.lookup("PR00673")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "raises NotFoundError when the approval does not exist" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.rm("NOPE")
      }.to raise_error(Claire::Approvals::NotFoundError, /no approval recorded for NOPE/)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "value validation in #record" do
    it "rejects a JIRA ticket" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record("MP-820")
      }.to raise_error(Claire::Approvals::InvalidValueError, /JIRA ticket/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a bare PR number" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record("17343")
      }.to raise_error(Claire::Approvals::InvalidValueError, /PR number/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a GitHub PR URL" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record("https://github.com/acima-credit/merchant_portal/pull/17343")
      }.to raise_error(Claire::Approvals::InvalidValueError, /URL/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a JIRA URL" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record("https://upbd.atlassian.net/browse/MP-820")
      }.to raise_error(Claire::Approvals::InvalidValueError, /URL/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects an empty string" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record("")
      }.to raise_error(Claire::Approvals::InvalidValueError, /cannot be empty/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects nil" do
      dir = Dir.mktmpdir
      store = make_approvals(dir)

      expect {
        store.record(nil)
      }.to raise_error(Claire::Approvals::InvalidValueError, /cannot be empty/)
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
