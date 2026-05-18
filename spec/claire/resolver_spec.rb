# frozen_string_literal: true

require "spec_helper"
require "claire/target"
require "claire/jira"
require "claire/github"
require "claire/cache"
require "claire/aliases"
require "claire/resolver"

RSpec.describe Claire::Resolver do
  # A no-op cache double used by specs that do not test cache behaviour.
  # It always misses (get returns nil) and silently accepts puts.
  def null_cache
    cache = instance_double(Claire::Cache)
    allow(cache).to receive(:get).and_return(nil)
    allow(cache).to receive(:put)
    cache
  end

  # Resolver requests these fields on every JIRA fetch (post-#45).
  RESOLVER_FIELDS = ["customfield_10762", "parent", "summary", "issuetype"].freeze

  # Build a JIRA fetch_issue stub with the post-#45 shape (summary + issuetype).
  # Defaults issuetype to "Story" — terminal stops must explicitly pass "Epic".
  def stub_issue(jira, key, project_code:, parent:, issuetype: "Story", summary: "#{key} summary")
    allow(jira).to receive(:fetch_issue).with(key, fields: RESOLVER_FIELDS).and_return(
      {
        "key" => key,
        "fields" => {
          "customfield_10762" => project_code,
          "parent" => parent ? { "key" => parent } : nil,
          "summary" => summary,
          "issuetype" => { "name" => issuetype },
        },
      },
    )
  end

  # Build the enriched walked_chain hop hash that the resolver pushes per ticket.
  # Defaults mirror stub_issue so a test can write `hop("MP-796")` and get a hop
  # that matches a default `stub_issue(jira, "MP-796", ...)`.
  def hop(key, summary: "#{key} summary", issuetype: "Story")
    { "key" => key, "summary" => summary, "issuetype" => issuetype }
  end

  describe ".resolve" do
    it "short-circuits on a raw project code and returns it without hitting JIRA" do
      jira = instance_double(Claire::Jira)
      allow(jira).to receive(:fetch_issue)

      resolution = Claire::Resolver.resolve("PR00151", jira: jira, cache: null_cache)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to be_nil
      expect(resolution.walked_chain).to eq([])
      expect(resolution.pr_url).to be_nil
      expect(jira).not_to have_received(:fetch_issue)
    end

    it "returns the project code when the issue has customfield_10762 set" do
      jira = instance_double(Claire::Jira)
      stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

      resolution = Claire::Resolver.resolve("MP-445", jira: jira, cache: null_cache)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to eq("MP-445")
    end

    it "walks one level up to the parent when the child's customfield_10762 is empty" do
      jira = instance_double(Claire::Jira)
      stub_issue(jira, "MP-796", project_code: "", parent: "MP-445")
      stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

      resolution = Claire::Resolver.resolve("MP-796", jira: jira, cache: null_cache)

      expect(resolution.project_code).to eq("PR00151")
      expect(resolution.jira_ticket).to eq("MP-796")
    end

    it "walks multiple levels up the parent chain to find the project code" do
      jira = instance_double(Claire::Jira)
      stub_issue(jira, "CHILD-1", project_code: nil, parent: "MID-1")
      stub_issue(jira, "MID-1", project_code: nil, parent: "TOP-1")
      stub_issue(jira, "TOP-1", project_code: "PR99999", parent: nil, issuetype: "Epic")

      resolution = Claire::Resolver.resolve("CHILD-1", jira: jira, cache: null_cache)

      expect(resolution.project_code).to eq("PR99999")
      expect(resolution.jira_ticket).to eq("CHILD-1")
    end

    it "raises with the walked chain when no project code is found after reaching the top" do
      jira = instance_double(Claire::Jira)
      stub_issue(jira, "MP-100", project_code: nil, parent: nil)

      expect {
        Claire::Resolver.resolve("MP-100", jira: jira, cache: null_cache)
      }.to raise_error(Claire::Resolver::NoProjectCodeError, /MP-100/)
    end

    it "raises when the parent chain exceeds depth 5" do
      jira = instance_double(Claire::Jira)
      # Chain DEEP-1 -> DEEP-2 -> ... -> DEEP-5 -> DEEP-6 (never reached).
      stub_issue(jira, "DEEP-1", project_code: nil, parent: "DEEP-2")
      stub_issue(jira, "DEEP-2", project_code: nil, parent: "DEEP-3")
      stub_issue(jira, "DEEP-3", project_code: nil, parent: "DEEP-4")
      stub_issue(jira, "DEEP-4", project_code: nil, parent: "DEEP-5")
      stub_issue(jira, "DEEP-5", project_code: nil, parent: "DEEP-6")

      expect {
        Claire::Resolver.resolve("DEEP-1", jira: jira, cache: null_cache)
      }.to raise_error(Claire::Resolver::DepthLimitError, /DEEP-1/)
    end

    it "accepts a JIRA URL, extracts the ticket key, and resolves normally" do
      jira = instance_double(Claire::Jira)
      stub_issue(jira, "MP-796", project_code: "", parent: "MP-445")
      stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

      resolution = Claire::Resolver.resolve("https://upbd.atlassian.net/browse/MP-796", jira: jira, cache: null_cache)

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
        stub_issue(jira, "MP-796", project_code: "", parent: "MP-445")
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve("17343", jira: jira, github: github, cache: null_cache)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-796")
        expect(resolution.pr_url).to eq("https://github.com/acima-credit/merchant_portal/pull/17343")
        expect(resolution.walked_chain).to eq([hop("MP-796"), hop("MP-445", issuetype: "Epic")])
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
        stub_issue(jira, "MP-796", project_code: "", parent: "MP-445")
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve(pr_url, jira: jira, github: github, cache: null_cache)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-796")
        expect(resolution.pr_url).to eq(pr_url)
        expect(resolution.walked_chain).to eq([hop("MP-796"), hop("MP-445", issuetype: "Epic")])
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
          Claire::Resolver.resolve("99", jira: jira, github: github, cache: null_cache)
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
          Claire::Resolver.resolve("99999", jira: jira, github: github, cache: null_cache)
        }.to raise_error(Claire::Github::NotFoundError)
      end
    end

    context "legacy project code filtering during the walk" do
      it "skips a legacy-pattern project code on the parent and walks further up to the grandparent" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-814", project_code: nil, parent: "MP-4")
        stub_issue(jira, "MP-4", project_code: "A25-1D861", parent: "UPP-953")
        stub_issue(jira, "UPP-953", project_code: "PR00206", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve("MP-814", jira: jira, cache: null_cache)

        expect(resolution.project_code).to eq("PR00206")
        expect(resolution.jira_ticket).to eq("MP-814")
        expect(resolution.walked_chain).to eq([
          hop("MP-814"),
          hop("MP-4"),
          hop("UPP-953", issuetype: "Epic"),
        ])
      end

      it "skips legacy codes at multiple levels and finds a non-legacy code further up" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "CHILD-1", project_code: nil, parent: "MID-1")
        stub_issue(jira, "MID-1", project_code: "B26-XYZ77", parent: "TOP-1")
        stub_issue(jira, "TOP-1", project_code: "C24-AAAAA", parent: "ROOT-1")
        stub_issue(jira, "ROOT-1", project_code: "PR99999", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve("CHILD-1", jira: jira, cache: null_cache)

        expect(resolution.project_code).to eq("PR99999")
        expect(resolution.walked_chain).to eq([
          hop("CHILD-1"),
          hop("MID-1"),
          hop("TOP-1"),
          hop("ROOT-1", issuetype: "Epic"),
        ])
      end

      it "raises NoProjectCodeError when the entire chain has only legacy codes" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "CHILD-1", project_code: "A25-AAAA1", parent: "TOP-1")
        stub_issue(jira, "TOP-1", project_code: "B26-BBBB2", parent: nil)

        expect {
          Claire::Resolver.resolve("CHILD-1", jira: jira, cache: null_cache)
        }.to raise_error(Claire::Resolver::NoProjectCodeError, /CHILD-1/)
      end

      it "accepts a legacy-shaped string typed directly by the user as a project code and returns it without a walk" do
        jira = instance_double(Claire::Jira)
        allow(jira).to receive(:fetch_issue)

        resolution = Claire::Resolver.resolve("A25-1D861", jira: jira, cache: null_cache)

        expect(resolution.project_code).to eq("A25-1D861")
        expect(resolution.jira_ticket).to be_nil
        expect(resolution.walked_chain).to eq([])
        expect(jira).not_to have_received(:fetch_issue)
      end
    end

    context "cache behaviour" do
      it "returns a Resolution from cache and does not call Jira or Github on a cache hit" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        allow(jira).to receive(:fetch_issue)
        allow(github).to receive(:fetch)
        allow(cache).to receive(:get).with("MP-820").and_return(
          {
            "pr_url" => nil,
            "jira_ticket" => "MP-820",
            "project_code" => "PR00151",
            "walked_chain" => ["MP-820"],
          },
        )

        resolution = Claire::Resolver.resolve("MP-820", jira: jira, github: github, cache: cache)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-820")
        expect(resolution.pr_url).to be_nil
        expect(resolution.walked_chain).to eq(["MP-820"])
        expect(jira).not_to have_received(:fetch_issue)
        expect(github).not_to have_received(:fetch)
      end

      it "falls back to an empty walked_chain for cache entries written before this field was added" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        allow(jira).to receive(:fetch_issue)
        allow(github).to receive(:fetch)
        # Simulate a legacy entry without the walked_chain key
        allow(cache).to receive(:get).with("MP-820").and_return(
          { "pr_url" => nil, "jira_ticket" => "MP-820", "project_code" => "PR00151" },
        )

        resolution = Claire::Resolver.resolve("MP-820", jira: jira, github: github, cache: cache)

        expect(resolution.walked_chain).to eq([])
      end

      it "resolves via Jira and writes per-step cache entries on a cache miss" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        allow(cache).to receive(:get).with("MP-445").and_return(nil)
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")
        allow(cache).to receive(:put)

        resolution = Claire::Resolver.resolve("MP-445", jira: jira, github: github, cache: cache)

        expect(resolution.project_code).to eq("PR00151")
        # One entry under the originating ticket (single-step walk: no
        # remaining chain to record) and one under the project code with
        # the stripped shape.
        expect(cache).to have_received(:put).with(
          key: "MP-445",
          pr_url: nil,
          jira_ticket: "MP-445",
          project_code: "PR00151",
          walked_chain: [],
          epic_key: "MP-445",
        )
        expect(cache).to have_received(:put).with(
          key: "PR00151",
          pr_url: nil,
          jira_ticket: nil,
          project_code: "PR00151",
          walked_chain: [],
          epic_key: "MP-445",
        )
      end

      it "skips cache and re-resolves when refresh: true, then rewrites per-step entries" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        existing_entry = {
          "pr_url" => nil,
          "jira_ticket" => "MP-445",
          "project_code" => "PR00151",
          "walked_chain" => [],
        }
        allow(cache).to receive(:get).with("MP-445").and_return(existing_entry)
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")
        allow(cache).to receive(:delete_by_resolution)
        allow(cache).to receive(:put)

        resolution = Claire::Resolver.resolve("MP-445", jira: jira, github: github, cache: cache, refresh: true)

        expect(resolution.project_code).to eq("PR00151")
        expect(jira).to have_received(:fetch_issue)
        expect(cache).to have_received(:delete_by_resolution).with(
          pr_url: nil,
          jira_ticket: "MP-445",
          project_code: "PR00151",
        )
        expect(cache).to have_received(:put).with(
          key: "MP-445",
          pr_url: nil,
          jira_ticket: "MP-445",
          project_code: "PR00151",
          walked_chain: [],
          epic_key: "MP-445",
        )
      end

      it "deletes the existing cache entry BEFORE live-resolving on refresh, even when live-resolve raises" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        existing_entry = {
          "pr_url" => nil,
          "jira_ticket" => "MP-820",
          "project_code" => "PR00151",
          "walked_chain" => ["MP-820"],
        }
        allow(cache).to receive(:get).with("MP-820").and_return(existing_entry)
        allow(cache).to receive(:delete_by_resolution)
        allow(jira).to receive(:fetch_issue).and_raise(RuntimeError, "network error")

        expect {
          Claire::Resolver.resolve("MP-820", jira: jira, github: github, cache: cache, refresh: true)
        }.to raise_error(RuntimeError, "network error")

        expect(cache).to have_received(:delete_by_resolution).with(
          pr_url: nil,
          jira_ticket: "MP-820",
          project_code: "PR00151",
        )
      end

      it "bypasses cache entirely for a raw project-code input and returns a trivial Resolution" do
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        allow(jira).to receive(:fetch_issue)
        allow(github).to receive(:fetch)
        allow(cache).to receive(:get)
        allow(cache).to receive(:put)

        resolution = Claire::Resolver.resolve("PR00151", jira: jira, github: github, cache: cache)

        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to be_nil
        expect(resolution.walked_chain).to eq([])
        expect(resolution.pr_url).to be_nil
        expect(jira).not_to have_received(:fetch_issue)
        expect(github).not_to have_received(:fetch)
        expect(cache).not_to have_received(:get)
        expect(cache).not_to have_received(:put)
      end

      context "alias substitution" do
        it "substitutes an alias before classification and returns a Resolution with the aliased project code" do
          jira = instance_double(Claire::Jira)
          github = instance_double(Claire::Github)
          aliases = instance_double(Claire::Aliases)

          allow(aliases).to receive(:lookup).with("BF").and_return("PR00673")

          resolution = Claire::Resolver.resolve("BF", jira: jira, github: github, cache: null_cache, aliases: aliases)

          expect(resolution.project_code).to eq("PR00673")
          expect(resolution.jira_ticket).to be_nil
          expect(resolution.pr_url).to be_nil
          expect(resolution.walked_chain).to eq([])
        end

        it "passes through unchanged when no alias matches" do
          jira = instance_double(Claire::Jira)
          aliases = instance_double(Claire::Aliases)

          allow(aliases).to receive(:lookup).with("PR00151").and_return(nil)

          resolution = Claire::Resolver.resolve("PR00151", jira: jira, cache: null_cache, aliases: aliases)

          expect(resolution.project_code).to eq("PR00151")
          expect(resolution.jira_ticket).to be_nil
        end
      end

      it "does not read a stale enriched cache entry when resolving a raw project-code input" do
        # Regression: a prior `check MP-796` may have cached an enriched entry under PR00151.
        # `log PR00151 30` must return jira_ticket: nil, NOT the cached "MP-796".
        jira = instance_double(Claire::Jira)
        github = instance_double(Claire::Github)
        cache = instance_double(Claire::Cache)

        allow(jira).to receive(:fetch_issue)
        allow(github).to receive(:fetch)
        allow(cache).to receive(:get)
        allow(cache).to receive(:put)

        resolution = Claire::Resolver.resolve("PR00151", jira: jira, github: github, cache: cache)

        expect(resolution.jira_ticket).to be_nil
        expect(resolution.project_code).to eq("PR00151")
        expect(cache).not_to have_received(:get)
        expect(cache).not_to have_received(:put)
      end
    end

    context "epic-aware walk (#45)" do
      it "populates epic_key with the key of the ticket where the walk stops" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve("MP-445", jira: jira, cache: null_cache)

        expect(resolution.epic_key).to eq("MP-445")
      end

      it "walks past a Story that has a non-legacy project code, stopping at the Epic ancestor" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-421", project_code: "PR00151", parent: "MP-445", issuetype: "Story")
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")

        resolution = Claire::Resolver.resolve("MP-421", jira: jira, cache: null_cache)

        expect(resolution.epic_key).to eq("MP-445")
        expect(resolution.project_code).to eq("PR00151")
        expect(resolution.jira_ticket).to eq("MP-421")
      end

      it "enriches each walked_chain hop with key, summary, and issuetype" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-715", project_code: nil, parent: "MP-421", summary: "Convert decorators")
        stub_issue(jira, "MP-421", project_code: nil, parent: "MP-445", summary: "es-MX date presentation")
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic", summary: "MX2 - MP Additional Adjustments")

        resolution = Claire::Resolver.resolve("MP-715", jira: jira, cache: null_cache)

        expect(resolution.walked_chain).to eq([
          { "key" => "MP-715", "summary" => "Convert decorators", "issuetype" => "Story" },
          { "key" => "MP-421", "summary" => "es-MX date presentation", "issuetype" => "Story" },
          { "key" => "MP-445", "summary" => "MX2 - MP Additional Adjustments", "issuetype" => "Epic" },
        ])
      end

      it "persists epic_key on every per-step cache entry so subsequent cache hits keep it" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-796", project_code: "", parent: "MP-445")
        stub_issue(jira, "MP-445", project_code: "PR00151", parent: nil, issuetype: "Epic")
        cache = instance_double(Claire::Cache)
        allow(cache).to receive(:get).and_return(nil)
        allow(cache).to receive(:put)

        Claire::Resolver.resolve("MP-796", jira: jira, cache: cache)

        expect(cache).to have_received(:put).with(hash_including(key: "MP-796", epic_key: "MP-445"))
        expect(cache).to have_received(:put).with(hash_including(key: "MP-445", epic_key: "MP-445"))
      end

      it "walks past an Epic that has no project code, continuing up the chain" do
        jira = instance_double(Claire::Jira)
        stub_issue(jira, "MP-421", project_code: nil, parent: "MP-445", issuetype: "Story")
        stub_issue(jira, "MP-445", project_code: nil, parent: "INI-1", issuetype: "Epic")
        stub_issue(jira, "INI-1", project_code: "PR00151", parent: nil, issuetype: "Initiative")
        # Initiative is not an Epic, so the walk does NOT stop here even though it has a project code.
        # The walk should keep going... but there's no further parent, so it raises.
        expect {
          Claire::Resolver.resolve("MP-421", jira: jira, cache: null_cache)
        }.to raise_error(Claire::Resolver::NoProjectCodeError)
      end
    end

    context "per-step chain caching (#27)" do
      # The chain MP-100 -> MP-200 -> MP-300, where MP-300 carries project
      # code PR00999. The "left-to-right" walk is what the resolver does
      # internally; the cached "walked_chain" for each entry is the
      # *remaining* chain from that ticket onward.
      def stub_chain_walk(jira)
        stub_issue(jira, "MP-100", project_code: "", parent: "MP-200")
        stub_issue(jira, "MP-200", project_code: "", parent: "MP-300")
        stub_issue(jira, "MP-300", project_code: "PR00999", parent: nil, issuetype: "Epic")
      end

      it "writes one cache entry per ticket in the walk plus one for the project code" do
        jira = instance_double(Claire::Jira)
        stub_chain_walk(jira)
        cache = instance_double(Claire::Cache)
        allow(cache).to receive(:get).and_return(nil)
        allow(cache).to receive(:put)

        Claire::Resolver.resolve("MP-100", jira: jira, cache: cache)

        # MP-100 — the originating ticket. No pr_url (input was a JIRA ticket,
        # not a PR). walked_chain is the rest: MP-200, MP-300.
        expect(cache).to have_received(:put).with(
          key: "MP-100",
          pr_url: nil,
          jira_ticket: "MP-100",
          project_code: "PR00999",
          walked_chain: [hop("MP-200"), hop("MP-300", issuetype: "Epic")],
          epic_key: "MP-300",
        )

        # MP-200 — an intermediate. No pr_url. walked_chain is what remains.
        expect(cache).to have_received(:put).with(
          key: "MP-200",
          pr_url: nil,
          jira_ticket: "MP-200",
          project_code: "PR00999",
          walked_chain: [hop("MP-300", issuetype: "Epic")],
          epic_key: "MP-300",
        )

        # MP-300 — the ticket that actually carries the project code.
        # walked_chain is empty because no further walk was needed.
        expect(cache).to have_received(:put).with(
          key: "MP-300",
          pr_url: nil,
          jira_ticket: "MP-300",
          project_code: "PR00999",
          walked_chain: [],
          epic_key: "MP-300",
        )

        # PR00999 — the project code itself. A project-code key carries no
        # jira_ticket and no pr_url: many tickets resolve to the same code,
        # so picking one would be structurally wrong.
        expect(cache).to have_received(:put).with(
          key: "PR00999",
          pr_url: nil,
          jira_ticket: nil,
          project_code: "PR00999",
          walked_chain: [],
          epic_key: "MP-300",
        )
      end

      it "stores pr_url only on the originating entry (not on intermediates or the project code)" do
        jira = instance_double(Claire::Jira)
        stub_chain_walk(jira)
        github = instance_double(Claire::Github)
        allow(github).to receive(:fetch).with("17347").and_return(
          { jira_ticket: "MP-100", pr_url: "https://github.com/acme/repo/pull/17347" },
        )
        cache = instance_double(Claire::Cache)
        allow(cache).to receive(:get).and_return(nil)
        allow(cache).to receive(:put)

        Claire::Resolver.resolve("17347", jira: jira, github: github, cache: cache)

        # Only MP-100 (the originating ticket from the PR) carries the pr_url.
        expect(cache).to have_received(:put).with(
          hash_including(key: "MP-100", pr_url: "https://github.com/acme/repo/pull/17347"),
        )

        # Intermediates have nil pr_url.
        expect(cache).to have_received(:put).with(hash_including(key: "MP-200", pr_url: nil))
        expect(cache).to have_received(:put).with(hash_including(key: "MP-300", pr_url: nil))

        # The project code key also has nil pr_url.
        expect(cache).to have_received(:put).with(hash_including(key: "PR00999", pr_url: nil))
      end

      it "lets a sibling resolution hit an intermediate cached ticket without calling Jira" do
        jira = instance_double(Claire::Jira)
        allow(jira).to receive(:fetch_issue)
        cache = instance_double(Claire::Cache)
        # MP-200 was cached earlier as an intermediate from a previous walk.
        allow(cache).to receive(:get).with("MP-200").and_return(
          {
            "pr_url" => nil,
            "jira_ticket" => "MP-200",
            "project_code" => "PR00999",
            "walked_chain" => ["MP-300"],
          },
        )

        resolution = Claire::Resolver.resolve("MP-200", jira: jira, cache: cache)

        expect(resolution.project_code).to eq("PR00999")
        expect(resolution.jira_ticket).to eq("MP-200")
        expect(resolution.walked_chain).to eq(["MP-300"])
        expect(jira).not_to have_received(:fetch_issue)
      end

      it "still cascade-deletes the whole family on refresh when any member is refreshed" do
        # delete_by_resolution already cascades by project_code (cache.rb), so
        # the new per-step entries — all sharing the same project_code — are
        # all caught by a single delete. This test pins that behaviour so a
        # future change to per-step caching cannot silently lose it.
        jira = instance_double(Claire::Jira)
        stub_chain_walk(jira)
        cache = instance_double(Claire::Cache)
        existing_entry = {
          "pr_url" => nil,
          "jira_ticket" => "MP-100",
          "project_code" => "PR00999",
          "walked_chain" => ["MP-200", "MP-300"],
        }
        allow(cache).to receive(:get).with("MP-100").and_return(existing_entry)
        allow(cache).to receive(:delete_by_resolution)
        allow(cache).to receive(:put)

        Claire::Resolver.resolve("MP-100", jira: jira, cache: cache, refresh: true)

        expect(cache).to have_received(:delete_by_resolution).with(
          pr_url: nil,
          jira_ticket: "MP-100",
          project_code: "PR00999",
        )
      end
    end
  end
end
