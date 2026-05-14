# frozen_string_literal: true

require "yaml"
require "json"
require "fileutils"

module Claire
  class Cache
    DEFAULT_PATH = File.expand_path("~/.config/claire/resolutions.yml")

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    # @return [Hash, nil] cached entry {"pr_url" => ..., "jira_ticket" => ..., "project_code" => ...} or nil
    def get(key)
      load_all[key.to_s]
    end

    # Writes entries for each non-nil identifier in the triple,
    # all pointing at the same hash value.
    def put(pr_url:, jira_ticket:, project_code:, walked_chain: [])
      entry = {
        "pr_url" => pr_url,
        "jira_ticket" => jira_ticket,
        "project_code" => project_code,
        "walked_chain" => walked_chain,
      }
      data = load_all
      [pr_url, jira_ticket, project_code].compact.each do |key|
        data[key.to_s] = entry
      end
      write_all(data)
    end

    # Cascade-delete: remove all entries whose project_code matches the given record's project_code.
    def delete_by_resolution(pr_url:, jira_ticket:, project_code:)
      data = load_all
      data.reject! { |_k, v| v["project_code"] == project_code }
      write_all(data)
    end

    private

    def load_all
      return {} unless File.exist?(@path)

      YAML.safe_load_file(@path, permitted_classes: [Symbol], aliases: true) || {}
    end

    def write_all(data)
      FileUtils.mkdir_p(File.dirname(@path))
      # Use JSON round-trip to break Ruby object identity so YAML does not emit aliases.
      plain = JSON.parse(JSON.generate(data))
      File.write(@path, plain.to_yaml)
    end
  end
end
