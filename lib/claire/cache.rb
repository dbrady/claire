# frozen_string_literal: true

require "yaml"
require "json"
require "fileutils"
require "claire/config"

module Claire
  class Cache
    # Bump when the on-disk entry shape changes. Old files (missing or
    # mismatched) are treated as empty — alpha product, no migration —
    # so a stale walked_chain shape can't leak into a post-#45 resolution.
    SCHEMA_VERSION = "v2-epic-aware"
    SCHEMA_KEY = "__schema_version__"

    def initialize(path: Claire::Config.default_resolutions_path)
      @path = path
    end

    # @return [Hash, nil] cached entry {"pr_url" => ..., "jira_ticket" => ..., "project_code" => ...} or nil
    def get(key)
      load_all[key.to_s]
    end

    # Writes a single entry under a single key. Callers (the resolver) are
    # responsible for writing per-step entries with shapes tailored to each
    # key — project-code keys carry only the project code, intermediate
    # jira-ticket keys carry their own ticket and project code (no pr_url
    # unless they were the originating PR-input), etc.
    def put(key:, pr_url: nil, jira_ticket: nil, project_code:, walked_chain: [], epic_key: nil)
      entry = {
        "pr_url" => pr_url,
        "jira_ticket" => jira_ticket,
        "project_code" => project_code,
        "walked_chain" => walked_chain,
        "epic_key" => epic_key,
      }
      data = load_all
      data[key.to_s] = entry
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

      raw = YAML.safe_load_file(@path, permitted_classes: [Symbol], aliases: true) || {}
      return {} unless raw[SCHEMA_KEY] == SCHEMA_VERSION
      raw.reject { |k, _v| k == SCHEMA_KEY }
    end

    def write_all(data)
      FileUtils.mkdir_p(File.dirname(@path))
      stamped = { SCHEMA_KEY => SCHEMA_VERSION }.merge(data)
      # Use JSON round-trip to break Ruby object identity so YAML does not emit aliases.
      plain = JSON.parse(JSON.generate(stamped))
      File.write(@path, plain.to_yaml)
    end
  end
end
