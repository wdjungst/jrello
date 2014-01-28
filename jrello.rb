require 'rubygems'
require 'open-uri'
require 'net/https'
require 'trello'
require 'active_support'
require 'active_record'
require 'yaml'
require File.expand_path(File.dirname(__FILE__) + '/lib/jira_service')
require File.expand_path(File.dirname(__FILE__) + '/lib/trello_service')
include Jira
include Trello_Service

JIRA_CONFIG = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/config/jira.yml'))

#for mac developent
module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    def use_ssl=(flag)
      if File.exists?('/etc/ssl/certs')
        self.ca_path = '/etc/ssl/certs'
      elsif File.exists?('/usr/local/Cellar/curl-ca-bundle/1.87/share/ca-bundle.crt')
        self.ca_file = '/usr/local/Cellar/curl-ca-bundle/1.87/share/ca-bundle.crt'
      end

      self.verify_mode = OpenSSL::SSL::VERIFY_PEER
      self.original_use_ssl = flag
    end
  end
end

@jira = Jira::Service.new
@trello = Trello_Service::Service.new
@open_tickets = {}
@done_tickets = {}
@issues = []
@counter = 0

def jira_search(list)
  @jira.search("project=#{JIRA_CONFIG['project']}&status=#{list}&sprint IN openSprints()")
end

def pull_tickets
  done = JIRA_CONFIG['done']
  @open_tickets = jira_search(JIRA_CONFIG['status'])
  @done_tickets = jira_search(done) unless done.blank?
  if @open_tickets['total'] == 0
    puts "nothing in #{JIRA_CONFIG['status']} currently"
    exit 0
  else
    compile_ticket_info(true)  unless @open_tickets.empty?
    compile_ticket_info(false) unless @done_tickets.empty?
  end
end

def compile_ticket_info(open)
  @issues.clear
  tickets = open ? @open_tickets : @done_tickets
  tickets['issues'].each do |issue|
    issue_data = {}
    issue_data[:key] = issue['key']
    if open
      issue_data[:desc] = issue['fields']['summary']
      issue_data[:assignee] = issue['fields']['assignee']['name']
      issue_data[:platform] = issue['fields']['components'].first['name']
    end
    @issues << issue_data
  end
  if open
    push_to_trello
  else
    move_to_done
  end
end

def push_to_trello
  @issues.each { |issue| @trello.add_card(id: issue[:key], desc: issue[:desc], member: issue[:assignee], label: issue[:platform]) }
end

def move_to_done
  @issues.each { |issue| @trello.move_card({ id: issue[:key] }, @counter += 1) } 
end

pull_tickets
