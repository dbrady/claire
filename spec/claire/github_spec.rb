# frozen_string_literal: true

require "spec_helper"
require "open3"
require "claire/github"

RSpec.describe Claire::Github do
  describe ".scrape_jira_key" do
    it "returns the first JIRA key found in text" do
      expect(described_class.scrape_jira_key("Foo bar MP-820 baz")).to eq("MP-820")
    end

    it "returns nil when no JIRA key is present" do
      expect(described_class.scrape_jira_key("plain text")).to be_nil
    end

    it "returns the first match when multiple JIRA keys are present" do
      expect(described_class.scrape_jira_key("multiple MP-820 and MP-999")).to eq("MP-820")
    end

    it "ignores lowercase ticket keys, returning the first uppercase match" do
      expect(described_class.scrape_jira_key("lowercase mp-820 mixed UPP-100")).to eq("UPP-100")
    end
  end

  describe "#fetch" do
    let(:github) { described_class.new }

    context "when gh returns a PR with a ticket key in the body" do
      it "returns pr_number, pr_url, and jira_ticket" do
        gh_json = JSON.generate({
          "number" => 17343,
          "title" => "Some unrelated title",
          "body" => "Fixes MP-796 in the body",
          "url" => "https://github.com/acima-credit/merchant_portal/pull/17343",
        })
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([gh_json, "", status])

        result = github.fetch("17343")

        expect(result[:pr_number]).to eq(17343)
        expect(result[:pr_url]).to eq("https://github.com/acima-credit/merchant_portal/pull/17343")
        expect(result[:jira_ticket]).to eq("MP-796")
      end
    end

    context "when gh returns a PR with a ticket key only in the title" do
      it "returns the ticket key found in the title" do
        gh_json = JSON.generate({
          "number" => 100,
          "title" => "MP-500 fix the thing",
          "body" => "No ticket in this body",
          "url" => "https://github.com/acima-credit/merchant_portal/pull/100",
        })
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([gh_json, "", status])

        result = github.fetch("100")

        expect(result[:jira_ticket]).to eq("MP-500")
      end
    end

    context "when neither title nor body contains a JIRA key" do
      it "raises NoJiraKeyError" do
        gh_json = JSON.generate({
          "number" => 99,
          "title" => "Refactor something",
          "body" => "No ticket here",
          "url" => "https://github.com/acima-credit/merchant_portal/pull/99",
        })
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([gh_json, "", status])

        expect {
          github.fetch("99")
        }.to raise_error(Claire::Github::NoJiraKeyError, /no JIRA key found in PR #99/)
      end
    end

    context "when gh exits non-zero with a not-found error" do
      it "raises NotFoundError" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(["", "could not resolve to a PullRequest", status])

        expect {
          github.fetch("99999")
        }.to raise_error(Claire::Github::NotFoundError, /99999/)
      end
    end

    context "when gh exits non-zero with an authentication error" do
      it "raises AuthenticationError" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(["", "authentication required: not logged in", status])

        expect {
          github.fetch("17343")
        }.to raise_error(Claire::Github::AuthenticationError)
      end
    end

    context "when gh exits non-zero with an unexpected error" do
      it "raises generic Error with stderr in the message" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(["", "something went terribly wrong", status])

        expect {
          github.fetch("17343")
        }.to raise_error(Claire::Github::Error, /something went terribly wrong/)
      end
    end
  end
end
