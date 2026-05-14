# frozen_string_literal: true

require "rbconfig"

module Claire
  module Clipboard
    COMMANDS = [
      ["pbcopy"],                             # macOS
      ["xclip", "-selection", "clipboard"],   # Linux + X11
      ["xsel", "--clipboard", "--input"],      # Linux alternative
      ["wl-copy"],                             # Linux + Wayland
    ].freeze

    # @return [Boolean] true on success, false if no clipboard tool available
    def self.copy(text)
      COMMANDS.each do |cmd|
        begin
          IO.popen(cmd, "w") { |io| io.write(text) }
          return true if Process.last_status.success?
        rescue Errno::ENOENT
          next
        end
      end
      false
    end

    def self.paste_shortcut
      case RbConfig::CONFIG["host_os"]
      when /darwin/ then "Cmd-V"
      else "Ctrl-V"
      end
    end
  end
end
