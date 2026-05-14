# frozen_string_literal: true

require "fileutils"
require "claire/config"

module Claire
  module CLI
    class Edit
      def initialize(config: nil, entries_path: nil, editor: ENV["EDITOR"] || "emacs")
        @config = config
        @entries_path_override = entries_path
        @editor = editor
      end

      def run
        entries_path = @entries_path_override || begin
          loaded_config = @config || begin
            Claire::Config.load
          rescue Claire::Config::NotFoundError
            nil
          end
          Claire::Config.default_entries_path(config: loaded_config)
        end

        FileUtils.mkdir_p(File.dirname(entries_path))
        FileUtils.touch(entries_path)

        # exec replaces the current process; no leftover claire PID after editor exits
        Kernel.exec(@editor, entries_path)
      end
    end
  end
end
