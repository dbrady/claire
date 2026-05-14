# frozen_string_literal: true

require "open3"
require "json"

module Claire
  class Github
    class Error < StandardError; end

    class NotFoundError < Error
      def initialize(pr_input)
        super("GitHub PR not found: #{pr_input}")
      end
    end

    class AuthenticationError < Error; end

    class NoJiraKeyError < Error
      def initialize(pr_number)
        super("no JIRA key found in PR ##{pr_number} title or body")
      end
    end

    JIRA_KEY_PATTERN = /\b[A-Z]+-\d+\b/

    # @param text [String]
    # @return [String, nil] first uppercase JIRA key found, or nil
    def self.scrape_jira_key(text)
      match = text.match(JIRA_KEY_PATTERN)
      match[0] if match
    end

    # @param pr_input [String, Integer] PR number or full GitHub PR URL
    # @return [Hash] with keys :pr_number, :pr_url, :jira_ticket
    def fetch(pr_input)
      stdout, stderr, status = Open3.capture3("gh", "pr", "view", pr_input.to_s, "--json", "body,title,url,number")

      unless status.success?
        raise_gh_error(pr_input, stderr)
      end

      data = JSON.parse(stdout)
      searchable_text = "#{data["title"]} #{data["body"]}"
      jira_ticket = self.class.scrape_jira_key(searchable_text)

      raise NoJiraKeyError.new(data["number"]) unless jira_ticket

      {
        pr_number: data["number"],
        pr_url: data["url"],
        jira_ticket: jira_ticket,
      }
    end

    private

    def raise_gh_error(pr_input, stderr)
      downcased = stderr.downcase
      if downcased.include?("could not resolve to a pullrequest")
        raise NotFoundError.new(pr_input)
      elsif downcased.include?("authentication") || downcased.include?("not logged in")
        raise AuthenticationError, stderr
      else
        raise Error, stderr
      end
    end
  end
end
