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
end
