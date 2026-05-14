# frozen_string_literal: true

require "spec_helper"
require "claire/config"
require "tmpdir"
require "yaml"
require "json"

RSpec.describe Claire::Config do
  describe ".write!" do
    it "writes a config file at the given path with atlassian credentials" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "config.yml")

      Claire::Config.write!(
        path: config_path,
        site_name: "example",
        email: "user@example.com",
        api_token: "tok123",
      )

      data = YAML.load_file(config_path)
      expect(data.dig("atlassian", "site_name")).to eq("example")
      expect(data.dig("atlassian", "email")).to eq("user@example.com")
      expect(data.dig("atlassian", "api_token")).to eq("tok123")
      expect(data.dig("user", "email")).to eq("user@example.com")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "creates parent directories if they do not exist" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "nested", "deep", "config.yml")

      Claire::Config.write!(
        path: config_path,
        site_name: "s",
        email: "e@e.com",
        api_token: "t",
      )

      expect(File.exist?(config_path)).to be(true)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "includes data_dir in the written config when provided" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "config.yml")
      data_dir = File.join(dir, "data")

      Claire::Config.write!(
        path: config_path,
        site_name: "example",
        email: "user@example.com",
        api_token: "tok123",
        data_dir: data_dir,
      )

      data = YAML.load_file(config_path)
      expect(data["data_dir"]).to eq(data_dir)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "omits data_dir from the written config when not provided" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "config.yml")

      Claire::Config.write!(
        path: config_path,
        site_name: "example",
        email: "user@example.com",
        api_token: "tok123",
      )

      data = YAML.load_file(config_path)
      expect(data.key?("data_dir")).to be(false)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".load" do
    it "returns a Config object with atlassian credentials accessible" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "config.yml")
      File.write(config_path, <<~YAML)
        atlassian:
          site_name: mysite
          email: me@example.com
          api_token: secrettoken
        user:
          email: me@example.com
      YAML

      config = Claire::Config.load(path: config_path)

      expect(config.site_name).to eq("mysite")
      expect(config.email).to eq("me@example.com")
      expect(config.api_token).to eq("secrettoken")
      expect(config.base_url).to eq("https://mysite.atlassian.net")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "populates data_dir on the returned config when the file carries the key" do
      dir = Dir.mktmpdir
      config_path = File.join(dir, "config.yml")
      explicit_data_dir = File.join(dir, "data")
      File.write(config_path, <<~YAML)
        atlassian:
          site_name: mysite
          email: me@example.com
          api_token: secrettoken
        user:
          email: me@example.com
        data_dir: #{explicit_data_dir}
      YAML

      config = Claire::Config.load(path: config_path)

      expect(config.data_dir).to eq(explicit_data_dir)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "raises an informative error when the config file does not exist" do
      expect {
        Claire::Config.load(path: "/nonexistent/path/config.yml")
      }.to raise_error(Claire::Config::NotFoundError, /config file not found/i)
    end
  end

  describe ".from_mcp_json" do
    it "extracts atlassian credentials from the atlassian-confluence server entry" do
      dir = Dir.mktmpdir
      mcp_path = File.join(dir, ".mcp.json")
      File.write(mcp_path, JSON.generate({
        "mcpServers" => {
          "atlassian-confluence" => {
            "env" => {
              "ATLASSIAN_SITE_NAME" => "upbd",
              "ATLASSIAN_USER_EMAIL" => "dev@example.com",
              "ATLASSIAN_API_TOKEN" => "mytoken",
            },
          },
        },
      }))

      credentials = Claire::Config.from_mcp_json(path: mcp_path)

      expect(credentials[:site_name]).to eq("upbd")
      expect(credentials[:email]).to eq("dev@example.com")
      expect(credentials[:api_token]).to eq("mytoken")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "raises an informative error when the mcp.json file does not exist" do
      expect {
        Claire::Config.from_mcp_json(path: "/nonexistent/.mcp.json")
      }.to raise_error(Claire::Config::NotFoundError, /mcp\.json/i)
    end

    it "raises an informative error when atlassian-confluence server entry is missing" do
      dir = Dir.mktmpdir
      mcp_path = File.join(dir, ".mcp.json")
      File.write(mcp_path, JSON.generate({ "mcpServers" => {} }))

      expect {
        Claire::Config.from_mcp_json(path: mcp_path)
      }.to raise_error(Claire::Config::MissingEntryError, /atlassian-confluence/i)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".default_config_dir" do
    it "returns ~/.config/claire when XDG_CONFIG_HOME is not set" do
      with_env_unset("XDG_CONFIG_HOME") do
        expected = File.expand_path("~/.config/claire")
        expect(Claire::Config.default_config_dir).to eq(expected)
      end
    end

    it "returns $XDG_CONFIG_HOME/claire when XDG_CONFIG_HOME is set" do
      dir = Dir.mktmpdir
      with_env("XDG_CONFIG_HOME", dir) do
        expect(Claire::Config.default_config_dir).to eq(File.join(dir, "claire"))
      end
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".default_config_path" do
    it "returns the config.yml inside default_config_dir" do
      dir = Dir.mktmpdir
      with_env("XDG_CONFIG_HOME", dir) do
        expected = File.join(dir, "claire", "config.yml")
        expect(Claire::Config.default_config_path).to eq(expected)
      end
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".default_data_dir" do
    it "returns ~/.local/share/claire when no env var is set and config: nil" do
      with_env_unset("XDG_DATA_HOME") do
        expected = File.expand_path("~/.local/share/claire")
        expect(Claire::Config.default_data_dir(config: nil)).to eq(expected)
      end
    end

    it "returns $XDG_DATA_HOME/claire when XDG_DATA_HOME is set and config: nil" do
      dir = Dir.mktmpdir
      with_env("XDG_DATA_HOME", dir) do
        expect(Claire::Config.default_data_dir(config: nil)).to eq(File.join(dir, "claire"))
      end
    ensure
      FileUtils.remove_entry(dir)
    end

    it "returns the config's data_dir when a loaded config carries one (highest priority)" do
      dir = Dir.mktmpdir
      explicit_data_dir = File.join(dir, "explicit-data")
      config = Claire::Config.new(
        site_name: "mysite",
        email: "me@example.com",
        api_token: "token",
        data_dir: explicit_data_dir,
      )

      with_env("XDG_DATA_HOME", File.join(dir, "should-not-use")) do
        expect(Claire::Config.default_data_dir(config: config)).to eq(explicit_data_dir)
      end
    ensure
      FileUtils.remove_entry(dir)
    end

    it "falls through to XDG_DATA_HOME when config: nil is passed" do
      dir = Dir.mktmpdir
      xdg_data_home = File.join(dir, "xdg-data")

      with_env("XDG_DATA_HOME", xdg_data_home) do
        expect(Claire::Config.default_data_dir(config: nil)).to eq(File.join(xdg_data_home, "claire"))
      end
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".default_entries_path" do
    it "joins onto default_data_dir" do
      dir = Dir.mktmpdir
      with_env("XDG_DATA_HOME", dir) do
        expected = File.join(dir, "claire", "entries.jsonl")
        expect(Claire::Config.default_entries_path(config: nil)).to eq(expected)
      end
    ensure
      FileUtils.remove_entry(dir)
    end

    it "uses the config's data_dir when passed a loaded config" do
      dir = Dir.mktmpdir
      config = Claire::Config.new(
        site_name: "s",
        email: "e@e.com",
        api_token: "t",
        data_dir: dir,
      )

      expected = File.join(dir, "entries.jsonl")
      expect(Claire::Config.default_entries_path(config: config)).to eq(expected)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe ".default_resolutions_path" do
    it "joins onto default_data_dir" do
      dir = Dir.mktmpdir
      with_env("XDG_DATA_HOME", dir) do
        expected = File.join(dir, "claire", "resolutions.yml")
        expect(Claire::Config.default_resolutions_path(config: nil)).to eq(expected)
      end
    ensure
      FileUtils.remove_entry(dir)
    end

    it "uses the config's data_dir when passed a loaded config" do
      dir = Dir.mktmpdir
      config = Claire::Config.new(
        site_name: "s",
        email: "e@e.com",
        api_token: "t",
        data_dir: dir,
      )

      expected = File.join(dir, "resolutions.yml")
      expect(Claire::Config.default_resolutions_path(config: config)).to eq(expected)
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  def with_env(name, value, &block)
    original = ENV.fetch(name, nil)
    ENV[name] = value
    block.call
  ensure
    original ? ENV[name] = original : ENV.delete(name)
  end

  def with_env_unset(name, &block)
    original = ENV.fetch(name, nil)
    ENV.delete(name)
    block.call
  ensure
    ENV[name] = original if original
  end
end
