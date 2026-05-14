# frozen_string_literal: true

require "claire/config"
require "claire/jira"
require "claire/github"
require "claire/resolver"
require "claire/clipboard"

module Claire
  module CLI
    class Check
      CLARITY_URL = "https://cppm10270.clarityppm.saas.broadcom.com/pm/#/projects/common"

      def initialize(resolver: Claire::Resolver, clipboard: Claire::Clipboard)
        @resolver = resolver
        @clipboard = clipboard
      end

      def run(input, refresh: false)
        resolution = @resolver.resolve(input, refresh: refresh)
        print_resolution(input, resolution)
      rescue Claire::Jira::AuthenticationError => e
        warn "claire: JIRA auth failed (HTTP #{e.status}). Run 'claire init' to refresh credentials."
        exit 1
      rescue Claire::Jira::NotFoundError => e
        warn "claire: JIRA issue not found: #{e.key}"
        exit 1
      rescue Claire::Jira::RequestError => e
        warn "claire: JIRA request failed (HTTP #{e.status}): #{e.body}"
        exit 1
      rescue Claire::Resolver::NoProjectCodeError => e
        warn "claire: #{e.message}"
        exit 1
      rescue Claire::Resolver::DepthLimitError => e
        warn "claire: #{e.message}"
        exit 1
      rescue Claire::Github::Error => e
        warn "claire: #{e.message}"
        exit 1
      rescue ArgumentError => e
        warn "claire: #{e.message}"
        exit 1
      end

      private

      def print_resolution(input, resolution)
        puts format_walk(input, resolution)
        puts "PR URL: #{resolution.pr_url}" if resolution.pr_url
        puts "Clarity: #{CLARITY_URL}"
        puts "  !!  manual mode: confirm you're approved for #{resolution.project_code} before logging time."
        copied = @clipboard.copy(resolution.project_code)
        if copied
          shortcut = @clipboard.paste_shortcut
          puts "           I have put #{resolution.project_code} in the clipboard. Open the URL, hit TAB and"
          puts "           then #{shortcut} to paste into the search field."
        end
      end

      def format_walk(input, resolution)
        if resolution.walked_chain.any?
          chain = resolution.walked_chain.join(" -> ")
          "#{chain} -> project code: #{resolution.project_code}"
        else
          "project code: #{resolution.project_code}"
        end
      end
    end
  end
end
