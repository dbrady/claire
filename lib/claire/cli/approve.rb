# frozen_string_literal: true

require "time"
require "claire/approvals"
require "claire/config"

module Claire
  module CLI
    class Approve
      def initialize(approvals: nil)
        @approvals = approvals
      end

      def run(argv)
        @approvals ||= begin
          config = Claire::Config.load
          Claire::Approvals.new(path: Claire::Config.default_approvals_path(config: config))
        rescue Claire::Config::NotFoundError
          Claire::Approvals.new(path: Claire::Config.default_approvals_path(config: nil))
        end

        sub_or_arg = argv.shift
        case sub_or_arg
        when "list", nil then run_list
        when "rm"        then run_rm(*argv)
        else
          run_add(sub_or_arg)
        end
      rescue Claire::Approvals::Error => e
        warn "claire approve: #{e.message}"
        exit 1
      end

      private

      def run_add(epic_key)
        previous = @approvals.record(epic_key)
        date = Time.now.strftime("%Y-%m-%d")
        if previous
          previous_date = Time.iso8601(previous).strftime("%Y-%m-%d")
          puts "re-recorded approval for #{epic_key} (was #{previous_date}, now #{date})"
        else
          puts "recorded approval for #{epic_key} on #{date}"
        end
      end

      def run_list
        listed = @approvals.list
        if listed.empty?
          puts "no approvals recorded"
          return
        end
        listed.each do |epic_key, timestamp|
          date = Time.iso8601(timestamp).strftime("%Y-%m-%d")
          puts "#{epic_key} -> #{date}"
        end
      end

      def run_rm(epic_key, *extra)
        if epic_key.nil? || !extra.empty?
          warn "Usage: claire approve rm <epic-key>"
          exit 1
        end
        @approvals.rm(epic_key)
        puts "removed approval for #{epic_key}"
      end
    end
  end
end
