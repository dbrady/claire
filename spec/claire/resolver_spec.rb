# frozen_string_literal: true

require "spec_helper"
require "claire/target"
require "claire/jira"
require "claire/github"
require "claire/resolver"

RSpec.describe Claire::Resolver do
  describe ".resolve" do
    it "short-circuits on a raw project code and returns it without hitting JIRA" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue)

      resolution = Claire::Resolver.resolve("PR00151", jira: jira)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to be_nil
      expect(resolution.walked_chain).to eq([])
      expect(resolution.pr_url).to be_nil
      expect(jira).not_to have_received(:fetch_issue)
    end

    it "returns the project code when the issue has customfield_10762 set" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue).with("MP-445", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-445",
          "fields" => {
            "customfield_10762" => "PR00151",
            "parent" => nil,
          },
        },
      )

      resolution = Claire::Resolver.resolve("MP-445", jira: jira)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to eq("MP-445")
    end

    it "walks one level up to the parent when the child's customfield_10762 is empty" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue).with("MP-796", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-796",
          "fields" => {
            "customfield_10762" => "",
            "parent" => { "key" => "MP-445" },
          },
        },
      )
      allow(jira).to receive(:fetch_issue).with("MP-445", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-445",
          "fields" => {
            "customfield_10762" => "PR00151",
            "parent" => nil,
          },
        },
      )

      resolution = Claire::Resolver.resolve("MP-796", jira: jira)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to eq("MP-796")
    end

    it "walks multiple levels up the parent chain to find the project code" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue).with("CHILD-1", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "CHILD-1",
          "fields" => {
            "customfield_10762" => nil,
            "parent" => { "key" => "MID-1" },
          },
        },
      )
      allow(jira).to receive(:fetch_issue).with("MID-1", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MID-1",
          "fields" => {
            "customfield_10762" => nil,
            "parent" => { "key" => "TOP-1" },
          },
        },
      )
      allow(jira).to receive(:fetch_issue).with("TOP-1", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "TOP-1",
          "fields" => {
            "customfield_10762" => "PR99999",
            "parent" => nil,
          },
        },
      )

      resolution = Claire::Resolver.resolve("CHILD-1", jira: jira)

      expect(resolution.project_code).to eq("PR99999")
      expect(resolution.jira_ticket).to eq("CHILD-1")
    end

    it "raises with the walked chain when no project code is found after reaching the top" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue).with("MP-100", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-100",
          "fields" => {
            "customfield_10762" => nil,
            "parent" => nil,
          },
        },
      )

      expect {
        Claire::Resolver.resolve("MP-100", jira: jira)
      }.to raise_error(Claire::Resolver::NoProjectCodeError, /MP-100/)
    end

    it "raises when the parent chain exceeds depth 5" do
      jira = instance_double(Claire::Jira)
      # Build a chain: DEEP-1 -> DEEP-2 -> DEEP-3 -> DEEP-4 -> DEEP-5 -> DEEP-6 (never reached)
      allow(jira).to receive(:fetch_issue).with("DEEP-1", fields: ["customfield_10762", "parent"]).and_return(
        { "key" => "DEEP-1", "fields" => { "customfield_10762" => nil, "parent" => { "key" => "DEEP-2" } } },
      )
      allow(jira).to receive(:fetch_issue).with("DEEP-2", fields: ["customfield_10762", "parent"]).and_return(
        { "key" => "DEEP-2", "fields" => { "customfield_10762" => nil, "parent" => { "key" => "DEEP-3" } } },
      )
      allow(jira).to receive(:fetch_issue).with("DEEP-3", fields: ["customfield_10762", "parent"]).and_return(
        { "key" => "DEEP-3", "fields" => { "customfield_10762" => nil, "parent" => { "key" => "DEEP-4" } } },
      )
      allow(jira).to receive(:fetch_issue).with("DEEP-4", fields: ["customfield_10762", "parent"]).and_return(
        { "key" => "DEEP-4", "fields" => { "customfield_10762" => nil, "parent" => { "key" => "DEEP-5" } } },
      )
      allow(jira).to receive(:fetch_issue).with("DEEP-5", fields: ["customfield_10762", "parent"]).and_return(
        { "key" => "DEEP-5", "fields" => { "customfield_10762" => nil, "parent" => { "key" => "DEEP-6" } } },
      )

      expect {
        Claire::Resolver.resolve("DEEP-1", jira: jira)
      }.to raise_error(Claire::Resolver::DepthLimitError, /DEEP-1/)
    end

    it "accepts a JIRA URL, extracts the ticket key, and resolves normally" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue).with("MP-796", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-796",
          "fields" => {
            "customfield_10762" => "",
            "parent" => { "key" => "MP-445" },
          },
        },
      )
      allow(jira).to receive(:fetch_issue).with("MP-445", fields: ["customfield_10762", "parent"]).and_return(
        {
          "key" => "MP-445",
          "fields" => {
            "customfield_10762" => "PR00151",
            "parent" => nil,
          },
        },
      )

      resolution = Claire::Resolver.resolve("https://upbd.atlassian.net/browse/MP-796", jira: jira)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to eq("MP-796")
    end

    context "when given a bare PR number" do
      it "fetches the PR, walks the JIRA chain, and returns a Resolution with pr_url populated" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)

        allow(github).to receive(:fetch).with("17343").and_return({
          pr_number: 17343,
          pr_url: "https://github.com/acima-credit/merchant_portal/pull/17343",
          jira_ticket: "MP-796",
        })
        allow(jira).to receive(:fetch_issue).with("MP-796", fields: ["customfield_10762", "parent"]).and_return(
          { "key" => "MP-796", "fields" => { "customfield_10762" => "", "parent" => { "key" => "MP-445" } } },
        )
        allow(jira).to receive(:fetch_issue).with("MP-445", fields: ["customfield_10762", "parent"]).and_return(
          { "key" => "MP-445", "fields" => { "customfield_10762" => "PR00151", "parent" => nil } },
        )

        resolution = Claire::Resolver.resolve("17343", jira: jira, github: github)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-796")
        expect(resolution.pr_url).to eq("https://github.com/acima-credit/merchant_portal/pull/17343")
        expect(resolution.walked_chain).to eq(["MP-796", "MP-445"])
      end
    end

    context "when given a GitHub PR URL" do
      it "fetches the PR, walks the JIRA chain, and returns a Resolution with pr_url populated" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        pr_url = "https://github.com/acima-credit/merchant_portal/pull/17343"

        allow(github).to receive(:fetch).with(pr_url).and_return({
          pr_number: 17343,
          pr_url: pr_url,
          jira_ticket: "MP-796",
        })
        allow(jira).to receive(:fetch_issue).with("MP-796", fields: ["customfield_10762", "parent"]).and_return(
          { "key" => "MP-796", "fields" => { "customfield_10762" => "", "parent" => { "key" => "MP-445" } } },
        )
        allow(jira).to receive(:fetch_issue).with("MP-445", fields: ["customfield_10762", "parent"]).and_return(
          { "key" => "MP-445", "fields" => { "customfield_10762" => "PR00151", "parent" => nil } },
        )

        resolution = Claire::Resolver.resolve(pr_url, jira: jira, github: github)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-796")
        expect(resolution.pr_url).to eq(pr_url)
        expect(resolution.walked_chain).to eq(["MP-796", "MP-445"])
      end
    end

    context "when Github raises NoJiraKeyError" do
      it "propagates the error" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)

        allow(github).to receive(:fetch).with("99").and_raise(
          Claire::Github::NoJiraKeyError.new(99),
        )

        expect {
          Claire::Resolver.resolve("99", jira: jira, github: github)
        }.to raise_error(Claire::Github::NoJiraKeyError)
      end
    end

    context "when Github raises NotFoundError" do
      it "propagates the error" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)

        allow(github).to receive(:fetch).with("99999").and_raise(
          Claire::Github::NotFoundError.new("99999"),
        )

        expect {
          Claire::Resolver.resolve("99999", jira: jira, github: github)
        }.to raise_error(Claire::Github::NotFoundError)
      end
    end
  end
end
