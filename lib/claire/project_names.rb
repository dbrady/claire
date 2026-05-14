# frozen_string_literal: true

require "yaml"
require "claire/config"

module Claire
  module ProjectNames
    DEFAULT_MAX_LABEL_WIDTH = 50
    ELLIPSIS = "…"

    def self.lookup(code, path: Claire::Config.default_project_names_path)
      data = load_all(path)
      data[code.to_s]
    end

    def self.label(code, path: Claire::Config.default_project_names_path, max_width: DEFAULT_MAX_LABEL_WIDTH)
      name = lookup(code, path: path)
      return code.to_s if name.nil? || name.empty?

      full = "#{code} - #{name}"
      return full if full.length <= max_width

      prefix = "#{code} - "
      cutoff = max_width - prefix.length - ELLIPSIS.length
      "#{prefix}#{name[0, cutoff]}#{ELLIPSIS}"
    end

    def self.load_all(path)
      return {} unless File.exist?(path)

      YAML.safe_load_file(path) || {}
    end
    private_class_method :load_all
  end
end
