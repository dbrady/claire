# frozen_string_literal: true

require "spec_helper"
require "claire/target"

RSpec.describe Claire::Target do
  describe ".classify" do
    it "classifies a standard JIRA ticket key as :ticket" do
      result = Claire::Target.classify("MP-820")
      expect(result).to eq(:ticket)
    end

    it "classifies a single-character project ticket as :ticket" do
      result = Claire::Target.classify("COR-1")
      expect(result).to eq(:ticket)
    end

    it "classifies a lowercase ticket key as :ticket (structural rule wins)" do
      result = Claire::Target.classify("abc-123")
      expect(result).to eq(:ticket)
    end

    it "classifies PR-12345 as :ticket (structural rule wins; no format validation)" do
      result = Claire::Target.classify("PR-12345")
      expect(result).to eq(:ticket)
    end

    it "classifies a bare multi-digit number as :pr_number" do
      result = Claire::Target.classify("17343")
      expect(result).to eq(:pr_number)
    end

    it "classifies a bare single digit as :pr_number" do
      result = Claire::Target.classify("1")
      expect(result).to eq(:pr_number)
    end

    it "classifies an atlassian.net URL as :jira_url" do
      result = Claire::Target.classify("https://upbd.atlassian.net/browse/MP-820")
      expect(result).to eq(:jira_url)
    end

    it "classifies a github.com pull URL as :pr_url" do
      result = Claire::Target.classify("https://github.com/acima-credit/merchant_portal/pull/17343")
      expect(result).to eq(:pr_url)
    end

    it "classifies a Clarity project code as :project_code" do
      result = Claire::Target.classify("PR00151")
      expect(result).to eq(:project_code)
    end

    it "classifies an arbitrary string as :project_code" do
      result = Claire::Target.classify("some-random-thing")
      expect(result).to eq(:project_code)
    end
  end
end
