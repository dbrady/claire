# frozen_string_literal: true

require "claire/aliases"
require "claire/config"

module Claire
  module CLI
    class Alias
      def initialize(aliases: nil)
        @aliases = aliases
      end

      def run(argv)
        @aliases ||= begin
          config = Claire::Config.load
          Claire::Aliases.new(path: Claire::Config.default_aliases_path(config: config))
        rescue Claire::Config::NotFoundError
          Claire::Aliases.new(path: Claire::Config.default_aliases_path(config: nil))
        end

        sub = argv.shift
        case sub
        when "add"  then run_add(*argv)
        when "rm"   then run_rm(*argv)
        when "list", nil then run_list
        else
          warn "claire alias: unknown subcommand '#{sub}'"
          exit 1
        end
      rescue Claire::Aliases::Error => e
        warn "claire alias: #{e.message}"
        exit 1
      end

      private

      def run_add(name, value, *extra)
        if name.nil? || value.nil? || !extra.empty?
          warn "Usage: claire alias add <name> <project-code>"
          exit 1
        end
        previous = @aliases.add(name, value)
        if previous
          puts "overwriting #{name}: #{previous} -> #{value}"
        else
          puts "alias #{name} -> #{value}"
        end
      end

      def run_rm(name, *extra)
        if name.nil? || !extra.empty?
          warn "Usage: claire alias rm <name>"
          exit 1
        end
        @aliases.rm(name)
        puts "removed alias #{name}"
      end

      def run_list
        listed = @aliases.list
        if listed.empty?
          puts "no aliases defined"
          return
        end
        listed.each { |name, value| puts "#{name} -> #{value}" }
      end
    end
  end
end
