# frozen_string_literal: true

require "yaml"
require "fileutils"
require "claire/config"
require "claire/target"

module Claire
  class Aliases
    NAME_PATTERN = /\A[A-Za-z0-9_-]+\z/

    class Error < StandardError; end
    class InvalidNameError < Error; end
    class InvalidValueError < Error; end
    class NotFoundError < Error; end

    def initialize(path: Claire::Config.default_aliases_path)
      @path = path
    end

    # Adds or overwrites the alias. Returns the previous value, or nil if it was new.
    def add(name, value)
      validate_name!(name)
      validate_value!(value)
      data = load_all
      previous = data[name]
      data[name] = value
      write_all(data)
      previous
    end

    def lookup(name)
      load_all[name.to_s]
    end

    def list
      load_all.sort.to_h
    end

    def rm(name)
      data = load_all
      raise NotFoundError, "no alias named #{name}" unless data.key?(name)
      data.delete(name)
      write_all(data)
    end

    private

    def validate_name!(name)
      unless name.is_a?(String) && name.match?(NAME_PATTERN)
        raise InvalidNameError, "alias names must be [A-Za-z0-9_-]+"
      end
    end

    def validate_value!(value)
      raise InvalidValueError, "alias value cannot be empty" if value.nil? || value.empty?
      case Claire::Target.classify(value)
      when :ticket
        raise InvalidValueError, "alias values must be project codes, not JIRA tickets. Got: #{value}"
      when :pr_number
        raise InvalidValueError, "alias values must be project codes, not PR numbers. Got: #{value}"
      when :pr_url, :jira_url
        raise InvalidValueError, "alias values must be project codes, not URLs. Got: #{value}"
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
