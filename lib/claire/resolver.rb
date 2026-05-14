# frozen_string_literal: true

require "claire/config"
require "claire/jira"
require "claire/github"
require "claire/cache"
require "claire/target"

module Claire
  class Resolver
    Resolution = Data.define(:pr_url, :jira_ticket, :walked_chain, :project_code)

    class NoProjectCodeError < StandardError
      def initialize(walked_chain)
        super("No project code found after walking: #{walked_chain.join(" -> ")}")
      end
    end

    class DepthLimitError < StandardError
      def initialize(walked_chain)
        super("Parent chain exceeded depth limit (5) starting from #{walked_chain.first}. Walked: #{walked_chain.join(" -> ")}")
      end
    end

    MAX_DEPTH = 5

    def self.resolve(input, jira: nil, github: nil, cache: nil, refresh: false)
      jira ||= Claire::Jira.new(Claire::Config.load)
      github ||= Claire::Github.new
      cache ||= Claire::Cache.new
      new(jira, github, cache).resolve(input, refresh: refresh)
    end

    def initialize(jira, github = Claire::Github.new, cache = Claire::Cache.new)
      @jira = jira
      @github = github
      @cache = cache
    end

    def resolve(input, refresh: false)
      # Raw project-code inputs bypass cache entirely (read AND write).
      # The resolution is trivial and there is nothing to cache. More importantly,
      # writing would clobber a richer enriched entry (jira_ticket, pr_url) that
      # a prior ticket- or PR-based lookup may have stored under the same key.
      category = Claire::Target.classify(input)
      return live_resolve_project_code(input) if category == :project_code

      cached = cached_resolution(input, refresh: refresh)
      return cached if cached

      resolution = live_resolve(input)
      @cache.put(
        pr_url: resolution.pr_url,
        jira_ticket: resolution.jira_ticket,
        project_code: resolution.project_code,
        walked_chain: resolution.walked_chain,
      )
      resolution
    end

    private

    # Returns a cached Resolution on a cache hit (when not refreshing), or nil
    # when the caller should live-resolve instead.
    # Side-effect: cascade-deletes the existing cache entry on refresh so that a
    # failing live-resolve leaves the cache empty rather than stale.
    def cached_resolution(input, refresh:)
      if refresh
        if (existing = @cache.get(input))
          @cache.delete_by_resolution(
            pr_url: existing["pr_url"],
            jira_ticket: existing["jira_ticket"],
            project_code: existing["project_code"],
          )
        end
        return nil
      end

      cached = @cache.get(input)
      return nil unless cached

      Resolution.new(
        pr_url: cached["pr_url"],
        jira_ticket: cached["jira_ticket"],
        walked_chain: cached["walked_chain"] || [],
        project_code: cached["project_code"],
      )
    end

    def live_resolve_project_code(input)
      Resolution.new(pr_url: nil, jira_ticket: nil, walked_chain: [], project_code: input)
    end

    def live_resolve(input)
      category = Claire::Target.classify(input)
      case category
      when :jira_url
        ticket_key = extract_ticket_from_jira_url(input)
        resolve_via_ticket(ticket_key)
      when :ticket
        resolve_via_ticket(input)
      when :pr_number, :pr_url
        pr_data = @github.fetch(input)
        resolve_via_ticket(pr_data[:jira_ticket], pr_url: pr_data[:pr_url])
      end
    end

    def resolve_via_ticket(ticket_key, pr_url: nil)
      walked_chain = []
      current_key = ticket_key

      (MAX_DEPTH + 1).times do
        if walked_chain.length >= MAX_DEPTH
          raise DepthLimitError.new(walked_chain)
        end

        walked_chain << current_key
        issue = @jira.fetch_issue(current_key, fields: ["customfield_10762", "parent"])
        fields = issue["fields"]
        project_code = fields["customfield_10762"]

        if project_code && !project_code.empty?
          return Resolution.new(
            pr_url: pr_url,
            jira_ticket: ticket_key,
            walked_chain: walked_chain,
            project_code: project_code,
          )
        end

        parent = fields["parent"]
        if parent.nil?
          raise NoProjectCodeError.new(walked_chain)
        end

        current_key = parent["key"]
      end
    end

    def extract_ticket_from_jira_url(url)
      match = url.match(/\/browse\/([A-Za-z]+-\d+)/)
      raise ArgumentError, "JIRA URL does not contain a ticket: #{url}" unless match
      match[1]
    end
  end
end
