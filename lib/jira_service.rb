require 'erb'
require 'json'
require 'net/https'
require 'yaml'

module Jira
  class Service
    JIRA_CONFIG = YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/../config/jira.yml'))
    JIRA_URL = "#{JIRA_CONFIG['jira_url']}/rest/api/2/search"

    def initialize(username = JIRA_CONFIG['username'], password = JIRA_CONFIG['password'])
      self.username = username
      self.password = password
    end

    def search(jql, max_results = 100)
      uri     = URI("#{JIRA_URL}?jql=#{ERB::Util.url_encode(jql)}&maxResults=#{max_results}")
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(username, password)

      JSON.parse(client.request(request).body)
    end

    private
    attr_accessor :username, :password

    def client
      unless @client
        uri = URI(JIRA_URL)
        @client = Net::HTTP.new(uri.hostname, uri.port)
        @client.use_ssl = true
      end

      @client
    end
  end
end
