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

    def initialize(path: Claire::Config.default_approvals_path)
      @path = path
    end

    # Records approval for project_code with a timestamp. Returns the previous
    # timestamp string, or nil if it was a new entry.
    def record(project_code, timestamp: Time.now)
      validate_project_code!(project_code)
      data = load_all
      previous = data[project_code]
      data[project_code] = timestamp.iso8601
      write_all(data)
      previous
    end

    def lookup(project_code)
      load_all[project_code.to_s]
    end

    def list
      load_all.sort.to_h
    end

    def rm(project_code)
      data = load_all
      raise NotFoundError, "no approval recorded for #{project_code}" unless data.key?(project_code)
      data.delete(project_code)
      write_all(data)
    end

    private

    def validate_project_code!(value)
      raise InvalidValueError, "project code cannot be empty" if value.nil? || value.to_s.empty?
      case Claire::Target.classify(value)
      when :ticket
        raise InvalidValueError, "argument must be a project code, not a JIRA ticket. Got: #{value}"
      when :pr_number
        raise InvalidValueError, "argument must be a project code, not a PR number. Got: #{value}"
      when :pr_url, :jira_url
        raise InvalidValueError, "argument must be a project code, not a URL. Got: #{value}"
      when :project_code
        # ok
      else
        raise InvalidValueError, "unrecognized value type for #{value.inspect}"
      end
    end

    def load_all
      return {} unless File.exist?(@path)
      YAML.safe_load_file(@path) || {}
    end

    def write_all(data)
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, YAML.dump(data))
    end
  end
end
