# frozen_string_literal: true

require "date"
require "claire/config"
require "claire/jira"
require "claire/github"
require "claire/resolver"
require "claire/duration"
require "claire/dates"
require "claire/log"
require "claire/project_names"

module Claire
  module CLI
    class Log
      def initialize(resolver_class: Claire::Resolver, config: nil, today: Date.today,
                     project_names: Claire::ProjectNames)
        @resolver_class = resolver_class
        @config = config
        @today = today
        @project_names = project_names
      end

      def run(target, duration_input, on: nil, note: nil, refresh: false)
        config = @config || Claire::Config.load
        log = Claire::Log.new(path: Claire::Config.default_entries_path(config: config))

        minutes = Claire::Duration.parse(duration_input)
        worked_on = Claire::Dates.parse(on, today: @today)
        resolution = @resolver_class.resolve(target, refresh: refresh, config: config)

        log.append(
          project_code: resolution.project_code,
          minutes: minutes,
          worked_on: worked_on,
          jira_ticket: resolution.jira_ticket,
          epic_key: resolution.epic_key,
          pr_url: resolution.pr_url,
          note: note,
        )

        ticket_suffix = " (#{resolution.jira_ticket})" if resolution.jira_ticket
        epic_suffix = " [#{resolution.epic_key}]" if resolution.epic_key
        label = @project_names.label(resolution.project_code)
        puts "logged #{minutes}m to #{label}#{epic_suffix}#{ticket_suffix} on #{worked_on}"
      rescue Claire::Jira::NotFoundError => e
        warn "claire: JIRA issue not found: #{e.key}"
        exit 1
      rescue Claire::Jira::AuthenticationError => e
        warn "claire: JIRA auth failed (HTTP #{e.status}). Run 'claire init' to refresh credentials."
        exit 1
      rescue Claire::Github::Error => e
        warn "claire: #{e.message}"
        exit 1
      rescue Claire::Resolver::NoProjectCodeError => e
        warn "claire: #{e.message}"
        exit 1
      rescue Claire::Resolver::DepthLimitError => e
        warn "claire: #{e.message}"
        exit 1
      rescue ArgumentError => e
        warn "claire: #{e.message}"
        exit 1
      end
    end
  end
end
