# frozen_string_literal: true

module Claire
  module Target
    TICKET_PATTERN     = /\A[A-Za-z]+-\d+\z/
    PR_NUMBER_PATTERN  = /\A\d+\z/
    JIRA_URL_PATTERN   = /\Ahttps?:\/\/[^\/]*\.atlassian\.net\//
    GITHUB_URL_PATTERN = /\Ahttps?:\/\/github\.com\//

    def self.classify(input)
      case input
      when JIRA_URL_PATTERN   then :jira_url
      when GITHUB_URL_PATTERN then :pr_url
      when TICKET_PATTERN     then :ticket
      when PR_NUMBER_PATTERN  then :pr_number
      else                         :project_code
      end
    end
  end
end
