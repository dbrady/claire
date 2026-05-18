# frozen_string_literal: true

require "claire/config"
require "claire/jira"
require "claire/github"
require "claire/cache"
require "claire/aliases"
require "claire/target"

module Claire
  class Resolver
    Resolution = Data.define(:pr_url, :jira_ticket, :walked_chain, :project_code, :epic_key)

    class NoProjectCodeError < StandardError
      def initialize(walked_chain)
        keys = walked_chain.map { |hop| hop.is_a?(Hash) ? hop["key"] : hop }
        super("No project code found after walking: #{keys.join(" -> ")}")
      end
    end

    class DepthLimitError < StandardError
      def initialize(walked_chain)
        keys = walked_chain.map { |hop| hop.is_a?(Hash) ? hop["key"] : hop }
        super("Parent chain exceeded depth limit (5) starting from #{keys.first}. Walked: #{keys.join(" -> ")}")
      end
    end

    MAX_DEPTH = 5

    # Values from the previous project tracking system (e.g. "A25-1D861" —
    # one letter, two-digit year, hyphen, short alphanumeric). Left in
    # customfield_10762 by data migration but not valid Clarity codes; walk
    # past them to the parent issue.
    LEGACY_PROJECT_CODE_PATTERN = /\A[A-Z]\d{2}-/

    # Clarity grants approval at the Epic level. The walk must stop on an
    # Epic that also carries a non-legacy project code; a Story or Sub-Task
    # with a project code is *not* the answer, even if customfield_10762 is
    # set — the user is responsible for two distinct epics rolling up to
    # the same project code, and we must surface the right one.
    JIRA_FIELDS = ["customfield_10762", "parent", "summary", "issuetype"].freeze
    EPIC_ISSUETYPE = "Epic"

    def self.resolve(input, jira: nil, github: nil, cache: nil, config: nil, aliases: nil, refresh: false)
      loaded_config = config || Claire::Config.load
      jira ||= Claire::Jira.new(loaded_config)
      github ||= Claire::Github.new
      cache ||= Claire::Cache.new(path: Claire::Config.default_resolutions_path(config: loaded_config))
      aliases ||= Claire::Aliases.new(path: Claire::Config.default_aliases_path(config: loaded_config))
      new(jira, github, cache, aliases).resolve(input, refresh: refresh)
    end

    def initialize(jira, github = Claire::Github.new, cache = Claire::Cache.new, aliases = Claire::Aliases.new)
      @jira = jira
      @github = github
      @cache = cache
      @aliases = aliases
    end

    def resolve(input, refresh: false)
      # Substitute alias before classifying. Aliases always point at project codes,
      # so the substituted value hits the project-code short-circuit below.
      if (resolved = @aliases.lookup(input))
        input = resolved
      end

      # Raw project-code inputs bypass cache entirely (read AND write).
      # The resolution is trivial and there is nothing to cache. More importantly,
      # writing would clobber a richer enriched entry (jira_ticket, pr_url) that
      # a prior ticket- or PR-based lookup may have stored under the same key.
      category = Claire::Target.classify(input)
      return live_resolve_project_code(input) if category == :project_code

      cached = cached_resolution(input, refresh: refresh)
      return cached if cached

      resolution = live_resolve(input)
      cache_per_step(resolution)
      resolution
    end

    private

    # Writes one cache entry per ticket walked plus one entry under the
    # project code. Each entry's walked_chain is the *suffix* from that
    # ticket onward, so a sibling walk that arrives at an intermediate
    # ticket gets a one-hop cache hit instead of replaying the whole walk.
    #
    # Per-key shapes:
    #   originating jira ticket  — own ticket; pr_url if input was a PR
    #   intermediate jira ticket — own ticket; nil pr_url
    #   project code             — only project code; nil ticket and pr_url
    def cache_per_step(resolution)
      project_code = resolution.project_code
      epic_key = resolution.epic_key
      full_chain = resolution.walked_chain

      full_chain.each_with_index do |hop, i|
        ticket_key = hop["key"]
        @cache.put(
          key: ticket_key,
          pr_url: i.zero? ? resolution.pr_url : nil,
          jira_ticket: ticket_key,
          project_code: project_code,
          walked_chain: full_chain[(i + 1)..],
          epic_key: epic_key,
        )
      end

      @cache.put(
        key: project_code,
        pr_url: nil,
        jira_ticket: nil,
        project_code: project_code,
        walked_chain: [],
        epic_key: epic_key,
      )
    end

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
        epic_key: cached["epic_key"],
      )
    end

    def live_resolve_project_code(input)
      Resolution.new(pr_url: nil, jira_ticket: nil, walked_chain: [], project_code: input, epic_key: nil)
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

        issue = @jira.fetch_issue(current_key, fields: JIRA_FIELDS)
        fields = issue["fields"]
        project_code = fields["customfield_10762"]
        issuetype = fields.dig("issuetype", "name")
        summary = fields["summary"]

        walked_chain << { "key" => current_key, "summary" => summary, "issuetype" => issuetype }

        is_epic = issuetype == EPIC_ISSUETYPE
        has_real_code = project_code && !project_code.empty? && !project_code.match?(LEGACY_PROJECT_CODE_PATTERN)

        if is_epic && has_real_code
          return Resolution.new(
            pr_url: pr_url,
            jira_ticket: ticket_key,
            walked_chain: walked_chain,
            project_code: project_code,
            epic_key: current_key,
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
