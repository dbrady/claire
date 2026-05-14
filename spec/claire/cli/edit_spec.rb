# frozen_string_literal: true

require "spec_helper"
require "claire/cli/edit"
require "tmpdir"

RSpec.describe Claire::CLI::Edit do
  describe "#run" do
    it "calls Kernel.exec with the configured editor and entries path" do
      tmpfile = File.join(Dir.mktmpdir, "entries.jsonl")
      edit = described_class.new(entries_path: tmpfile, editor: "vim")
      allow(Kernel).to receive(:exec)

      edit.run

      expect(Kernel).to have_received(:exec).with("vim", tmpfile)
    end

    it "creates the entries file if it does not exist" do
      tmpdir = Dir.mktmpdir
      tmpfile = File.join(tmpdir, "subdir", "entries.jsonl")
      edit = described_class.new(entries_path: tmpfile, editor: "vim")
      allow(Kernel).to receive(:exec)

      edit.run

      expect(File.exist?(tmpfile)).to be true
    end

    it "does not clobber an existing entries file" do
      tmpfile = File.join(Dir.mktmpdir, "entries.jsonl")
      File.write(tmpfile, '{"existing":"data"}')
      edit = described_class.new(entries_path: tmpfile, editor: "vim")
      allow(Kernel).to receive(:exec)

      edit.run

      expect(File.read(tmpfile)).to eq('{"existing":"data"}')
    end

    it "defaults to emacs when EDITOR is not set" do
      with_editor_unset do
        edit = described_class.new(entries_path: File.join(Dir.mktmpdir, "entries.jsonl"))
        expect(edit.instance_variable_get(:@editor)).to eq("emacs")
      end
    end

    it "uses EDITOR env var when set" do
      with_editor("nano") do
        edit = described_class.new(entries_path: File.join(Dir.mktmpdir, "entries.jsonl"))
        expect(edit.instance_variable_get(:@editor)).to eq("nano")
      end
    end
  end

  def with_editor(value, &block)
    original = ENV.fetch("EDITOR", nil)
    ENV["EDITOR"] = value
    block.call
  ensure
    original ? ENV["EDITOR"] = original : ENV.delete("EDITOR")
  end

  def with_editor_unset(&block)
    original = ENV.fetch("EDITOR", nil)
    ENV.delete("EDITOR")
    block.call
  ensure
    ENV["EDITOR"] = original if original
  end
end
