# frozen_string_literal: true

require "time"
require "claire/config"
require "claire/jira"
require "claire/github"
require "claire/resolver"
require "claire/clipboard"
require "claire/project_names"
require "claire/approvals"

module Claire
  module CLI
    class Check
      CLARITY_URL = "https://cppm10270.clarityppm.saas.broadcom.com/pm/#/projects/common"

      def initialize(resolver: Claire::Resolver, clipboard: Claire::Clipboard,
                     project_names: Claire::ProjectNames, approvals: nil)
        @resolver = resolver
        @clipboard = clipboard
        @project_names = project_names
        @approvals = approvals || Claire::Approvals.new(
          path: Claire::Config.default_approvals_path(config: nil),
        )
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
        approval = @approvals.lookup(resolution.project_code)
        if approval
          date = Time.iso8601(approval).strftime("%Y-%m-%d")
          puts "        [OK] You manually recorded #{resolution.project_code} as approved on #{date}."
        else
          puts "  !!  manual mode: confirm you're approved for #{resolution.project_code} before logging time."
          copied = @clipboard.copy(resolution.project_code)
          if copied
            shortcut = @clipboard.paste_shortcut
            puts "           I have put #{resolution.project_code} in the clipboard. Open the URL, hit TAB and"
            puts "           then #{shortcut} to paste into the search field."
          end
        end
      end

      def format_walk(input, resolution)
        label = @project_names.label(resolution.project_code)
        if resolution.walked_chain.any?
          # Transitional: #45 enriches walked_chain hops to {key, summary, issuetype}.
          # #46 will rewrite this output as a nested tree using the new data; for now
          # we render the key chain as before so the existing UX keeps working.
          keys = resolution.walked_chain.map { |hop| hop.is_a?(Hash) ? hop["key"] : hop }
          chain = keys.join(" -> ")
          "#{chain} -> project code: #{label}"
        else
          "project code: #{label}"
        end
      end
    end
  end
end
