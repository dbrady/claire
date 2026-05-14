# frozen_string_literal: true

require "spec_helper"
require "claire/clipboard"

RSpec.describe Claire::Clipboard do
  describe ".copy" do
    it "copies text via the first available command and returns true" do
      io = StringIO.new
      allow(IO).to receive(:popen).with(["pbcopy"], "w").and_yield(io)
      status = instance_double(Process::Status, success?: true)
      allow(Process).to receive(:last_status).and_return(status)

      result = Claire::Clipboard.copy("PR00632")

      expect(result).to eq(true)
      expect(io.string).to eq("PR00632")
    end

    it "falls through to the next command when the first raises Errno::ENOENT" do
      io = StringIO.new
      allow(IO).to receive(:popen).with(["pbcopy"], "w").and_raise(Errno::ENOENT)
      allow(IO).to receive(:popen).with(["xclip", "-selection", "clipboard"], "w").and_yield(io)
      status = instance_double(Process::Status, success?: true)
      allow(Process).to receive(:last_status).and_return(status)

      result = Claire::Clipboard.copy("PR00632")

      expect(result).to eq(true)
      expect(io.string).to eq("PR00632")
    end

    it "returns false when all commands raise Errno::ENOENT" do
      allow(IO).to receive(:popen).and_raise(Errno::ENOENT)

      result = Claire::Clipboard.copy("PR00632")

      expect(result).to eq(false)
    end

    it "falls through to the next command when a command exits nonzero" do
      io_first = StringIO.new
      io_second = StringIO.new
      failing_status = instance_double(Process::Status, success?: false)
      succeeding_status = instance_double(Process::Status, success?: true)

      allow(IO).to receive(:popen).with(["pbcopy"], "w").and_yield(io_first)
      allow(IO).to receive(:popen).with(["xclip", "-selection", "clipboard"], "w").and_yield(io_second)
      allow(Process).to receive(:last_status).and_return(failing_status, succeeding_status)

      result = Claire::Clipboard.copy("PR00632")

      expect(result).to eq(true)
      expect(io_second.string).to eq("PR00632")
    end

    it "returns false when a command is found but all exit nonzero" do
      io = StringIO.new
      failing_status = instance_double(Process::Status, success?: false)
      allow(IO).to receive(:popen).and_yield(io)
      allow(Process).to receive(:last_status).and_return(failing_status)

      result = Claire::Clipboard.copy("PR00632")

      expect(result).to eq(false)
    end
  end

  describe ".paste_shortcut" do
    it "returns Cmd-V on macOS" do
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin23")

      expect(Claire::Clipboard.paste_shortcut).to eq("Cmd-V")
    end

    it "returns Ctrl-V on Linux" do
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("linux-gnu")

      expect(Claire::Clipboard.paste_shortcut).to eq("Ctrl-V")
    end
  end
end
