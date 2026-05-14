# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "claire/target"
require "claire/aliases"

RSpec.describe Claire::Aliases do
  def make_aliases(dir)
    path = File.join(dir, "aliases.yml")
    described_class.new(path: path)
  end

  describe "#add and #lookup" do
    it "writes the alias so that lookup returns the project code" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      store.add("BF", "PR00673")

      expect(store.lookup("BF")).to eq("PR00673")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil (previous value) when adding a brand-new alias" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      previous = store.add("BF", "PR00673")

      expect(previous).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "overwrites an existing alias and returns the previous value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)
      store.add("BF", "PR00673")

      previous = store.add("BF", "PR99999")

      expect(previous).to eq("PR00673")
      expect(store.lookup("BF")).to eq("PR99999")
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#lookup" do
    it "returns nil when the file does not exist" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect(store.lookup("BF")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns nil when the key is not in the file" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)
      store.add("OTHER", "PR00001")

      expect(store.lookup("BF")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#list" do
    it "returns an alphabetical hash of all aliases" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)
      store.add("ZULU", "PR00002")
      store.add("ALPHA", "PR00001")
      store.add("MID", "PR00003")

      result = store.list

      expect(result.keys).to eq(["ALPHA", "MID", "ZULU"])
      expect(result).to eq({ "ALPHA" => "PR00001", "MID" => "PR00003", "ZULU" => "PR00002" })
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns an empty hash when the file does not exist" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect(store.list).to eq({})
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "#rm" do
    it "removes the entry so that subsequent lookup returns nil" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)
      store.add("BF", "PR00673")

      store.rm("BF")

      expect(store.lookup("BF")).to be_nil
    ensure
      FileUtils.remove_entry(dir)
    end

    it "raises NotFoundError when the alias does not exist" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.rm("NOPE")
      }.to raise_error(Claire::Aliases::NotFoundError, /no alias named NOPE/)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "name validation" do
    it "rejects a name with whitespace" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("weird name", "PR00673")
      }.to raise_error(Claire::Aliases::InvalidNameError, /\[A-Za-z0-9_-\]/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a name with slashes" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("bad/name", "PR00673")
      }.to raise_error(Claire::Aliases::InvalidNameError, /\[A-Za-z0-9_-\]/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects an empty name" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("", "PR00673")
      }.to raise_error(Claire::Aliases::InvalidNameError)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "accepts alphanumeric names, underscores, and hyphens" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect { store.add("BF", "PR00673") }.not_to raise_error
      expect { store.add("my_alias", "PR00001") }.not_to raise_error
      expect { store.add("dash-name", "PR00002") }.not_to raise_error
      expect { store.add("num123", "PR00003") }.not_to raise_error
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "value validation" do
    it "rejects a JIRA ticket value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("EPIC", "MP-820")
      }.to raise_error(Claire::Aliases::InvalidValueError, /JIRA tickets/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a bare PR number value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("BF", "17343")
      }.to raise_error(Claire::Aliases::InvalidValueError, /PR numbers/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a GitHub URL value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("BF", "https://github.com/acima-credit/merchant_portal/pull/17343")
      }.to raise_error(Claire::Aliases::InvalidValueError, /URLs/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a JIRA URL value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("BF", "https://upbd.atlassian.net/browse/MP-820")
      }.to raise_error(Claire::Aliases::InvalidValueError, /URLs/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects a nil value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("BF", nil)
      }.to raise_error(Claire::Aliases::InvalidValueError, /cannot be empty/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "rejects an empty string value" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect {
        store.add("BF", "")
      }.to raise_error(Claire::Aliases::InvalidValueError, /cannot be empty/)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "accepts a plain project code like PR00673" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect { store.add("BF", "PR00673") }.not_to raise_error
    ensure
      FileUtils.remove_entry(dir)
    end

    it "accepts an opaque project code that looks like a strange string" do
      dir = Dir.mktmpdir
      store = make_aliases(dir)

      expect { store.add("BF", "TSK-X-Y") }.not_to raise_error
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
