# frozen_string_literal: true

require "fileutils"
require "claire/config"

module Claire
  module CLI
    class Edit
      def initialize(entries_path: Claire::Config.default_entries_path,
                     editor: ENV["EDITOR"] || "emacs")
        @entries_path = entries_path
        @editor = editor
      end

      def run
        FileUtils.mkdir_p(File.dirname(@entries_path))
        FileUtils.touch(@entries_path)

        # exec replaces the current process; no leftover claire PID after editor exits
        Kernel.exec(@editor, @entries_path)
      end
    end
  end
end
