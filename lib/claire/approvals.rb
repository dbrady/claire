# frozen_string_literal: true

require "yaml"
require "fileutils"
require "time"
require "claire/config"
require "claire/target"

module Claire
  class Approvals
    class Error < StandardError; end
    class InvalidValueError < Error; end
    class NotFoundError < Error; end

    # Approvals are now keyed by the epic JIRA key (e.g. "MP-445"), not by
    # the project code. Clarity grants approval per epic; two epics under
    # the same project code can have different approval states.
    SCHEMA_VERSION = "v2-epic-key"
    SCHEMA_KEY = "__schema_version__"

    def initialize(path: Claire::Config.default_approvals_path)
      @path = path
    end

    # Records approval for an epic key with a timestamp. Returns the previous
    # timestamp string, or nil if it was a new entry.
    def record(epic_key, timestamp: Time.now)
      validate_epic_key!(epic_key)
      data = load_all
      previous = data[epic_key]
      data[epic_key] = timestamp.iso8601
      write_all(data)
      previous
    end

    def lookup(epic_key)
      return nil if epic_key.nil?
      load_all[epic_key.to_s]
    end

    def list
      load_all.sort.to_h
    end

    def rm(epic_key)
      data = load_all
      raise NotFoundError, "no approval recorded for #{epic_key}" unless data.key?(epic_key)
      data.delete(epic_key)
      write_all(data)
    end

    private

    def validate_epic_key!(value)
      raise InvalidValueError, "epic key cannot be empty" if value.nil? || value.to_s.empty?
      case Claire::Target.classify(value)
      when :project_code
        raise InvalidValueError, "argument must be an epic JIRA key, not a project code. Got: #{value}"
      when :pr_number
        raise InvalidValueError, "argument must be an epic JIRA key, not a PR number. Got: #{value}"
      when :pr_url, :jira_url
        raise InvalidValueError, "argument must be an epic JIRA key, not a URL. Got: #{value}"
      when :ticket
        # ok -- epic keys take the JIRA ticket shape
      else
        raise InvalidValueError, "unrecognized value type for #{value.inspect}"
      end
    end

    # Pre-#48 files were keyed by project code with no schema sentinel.
    # Treat them as empty rather than migrating; the right epic for each
    # project-code approval can't be derived from the file alone.
    def load_all
      return {} unless File.exist?(@path)
      raw = YAML.safe_load_file(@path) || {}
      return {} unless raw[SCHEMA_KEY] == SCHEMA_VERSION
      raw.reject { |k, _v| k == SCHEMA_KEY }
    end

    def write_all(data)
      FileUtils.mkdir_p(File.dirname(@path))
      stamped = { SCHEMA_KEY => SCHEMA_VERSION }.merge(data)
      File.write(@path, YAML.dump(stamped))
    end
  end
end
