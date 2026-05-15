# frozen_string_literal: true

require "spec_helper"
require "claire/cli/doctor"
require "tmpdir"
require "yaml"

# Doctor is the heal-and-bootstrap verb. It is intentionally equivalent to
# Init on the heal path — same checks, same fixes, same output — because
# both verbs are front doors to the same idempotent heal action (#38). The
# difference is which mental model the user is in when they type.
RSpec.describe Claire::CLI::Doctor do
  it "heals a configured machine without raising and exits cleanly" do
    dir = Dir.mktmpdir("claire-doctor-spec")
    config_dir = File.join(dir, ".config", "claire")
    data_dir = File.join(dir, ".local", "share", "claire")
    FileUtils.mkdir_p(config_dir)
    FileUtils.mkdir_p(data_dir)
    config_path = File.join(config_dir, "config.yml")
    Claire::Config.write!(
      path: config_path,
      site_name: "example",
      email: "alice@example.com",
      api_token: "tok",
      data_dir: data_dir,
    )

    jira_class = class_double(Claire::Jira)
    jira_instance = instance_double(Claire::Jira)
    allow(jira_class).to receive(:new).and_return(jira_instance)
    allow(jira_instance).to receive(:ping_myself).and_return("Alice")
    allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

    doctor = described_class.new(config_path: config_path, jira_class: jira_class)

    expect { doctor.run }.not_to raise_error
  ensure
    FileUtils.remove_entry(dir)
  end

  it "strips a phantom user: section from an existing config.yml" do
    dir = Dir.mktmpdir("claire-doctor-phantom-spec")
    config_dir = File.join(dir, ".config", "claire")
    data_dir = File.join(dir, ".local", "share", "claire")
    FileUtils.mkdir_p(config_dir)
    FileUtils.mkdir_p(data_dir)
    config_path = File.join(config_dir, "config.yml")
    File.write(config_path, YAML.dump(
      "atlassian" => {
        "site_name" => "example",
        "email" => "alice@example.com",
        "api_token" => "tok",
      },
      "user" => { "email" => "alice@example.com" },
      "data_dir" => data_dir,
    ))

    jira_class = class_double(Claire::Jira)
    jira_instance = instance_double(Claire::Jira)
    allow(jira_class).to receive(:new).and_return(jira_instance)
    allow(jira_instance).to receive(:ping_myself).and_return("Alice")
    allow(Claire::Config).to receive(:default_data_dir).with(config: nil).and_return(data_dir)

    doctor = described_class.new(config_path: config_path, jira_class: jira_class)
    doctor.run

    data = YAML.load_file(config_path)
    expect(data.key?("user")).to be(false)
  ensure
    FileUtils.remove_entry(dir)
  end
end
