# frozen_string_literal: true

require "claire/config"
require "claire/jira"
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

    def self.resolve(input, jira: nil)
      jira ||= Claire::Jira.new(Claire::Config.load)
      new(jira).resolve(input)
    end

    def initialize(jira)
      @jira = jira
    end

    def resolve(input)
      category = Claire::Target.classify(input)

      case category
      when :project_code
        Resolution.new(pr_url: nil, jira_ticket: nil, walked_chain: [], project_code: input)
      when :jira_url
        ticket_key = extract_ticket_from_jira_url(input)
        resolve_ticket(ticket_key, original_input: input)
      when :ticket
        resolve_ticket(input, original_input: input)
      when :pr_number, :pr_url
        raise NotImplementedError, "PR resolution is not yet implemented (coming in S3)"
      end
    end

    private

    def resolve_ticket(ticket_key, original_input:)
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
            pr_url: nil,
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
