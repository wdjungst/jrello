require 'trello'
include Trello
include Trello::Authorization

module Trello_Service
  class Service
     CONFIG = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/../config/trello.yml'))
     Trello::Authorization.const_set :AuthPolicy, OAuthPolicy
     OAuthPolicy.consumer_credential = OAuthCredential.new(CONFIG['public_key'], CONFIG['secret'])
     OAuthPolicy.token = OAuthCredential.new(CONFIG['token'], nil)

     def initialize
       @labels = CONFIG['labels'].first 
       @board = Board.find(CONFIG['trello_board'])
       @push_list  = List.find(CONFIG['push_list']) 
       @done_list = List.find(CONFIG['done_list'])
       @additional_lists = []
       lists = CONFIG['additional_lists']
       lists.each { |list| @additional_lists << List.find(list) } unless lists.blank?
       update_cards
     end

     def add_card(ticket)
       name = "[auto] #{ticket[:id]}"
       description = ticket[:desc]
       jira_user = ticket[:member]
       label = ticket[:label]
       label_color = @labels[label]
       values = card_status(name, description, jira_user)
       if !values[:exists]
         card = Card.create(name: name, list_id: @push_list.id, desc: description)
	 card.add_label(label_color) if @labels.has_key? label
	 card.add_member(find_member(jira_user)) unless jira_user.blank? rescue nil
       else
         if values[:update_description]
           card = Card.find(values[:id])
	   card.desc = description
	   card.save 
	 end
       end
     end

     def move_card(ticket, counter)
       update_cards if counter == 1 
       @cards.each do |card|
	 unless card.list.id == @done_list || !card.name.include?("[auto]") 
	   if card.name == "[auto] #{ticket[:id]}"
	     card.move_to_list(@done_list)
	     break
	   end
	 end
       end
     end
     

     def card_status(card_name, card_desc, member = '')
       exists = false 
       update_description = false
       id = ''
       @cards.each do |card| 
         if card.name == card_name
           exists = true
	   if card.desc != card_desc
             update_description = true
	     id = card.id
	   end
	   update_members(card, member)
         end
       end
       { exists: exists, update_description: update_description, id: id }
     end

     def find_member(member)
       Member.find(CONFIG['members'].first[member]) rescue nil
     end

     def update_members(card, member)
       members = card.members
       return unless CONFIG['members'].first.has_key? member
       if member.blank? && members.count > 0
         card.remove_member(members.first)
	 card.save
       elsif !member.blank? && members.count > 0
         member = find_member(member)
         if member != members.first
	   card.remove_member(members.first)
	   card.add_member(member)
	   card.save
	 end
       elsif !member.blank? && members.count == 0
         member = find_member(member)
	 card.add_member(member)
	 card.save
       end
     end

     def remove_cards(jira_list)
       update_cards
       @cards.each do |card|
	 remove_card = true
         jira_list.each do |jira_card|
           remove_card = false if card.name == "[auto] #{jira_card[:name]}"  
	 end
	 archive_card(card) if remove_card
       end
     end

     def archive_card(card)
       card.close!
     end
     
     def update_cards
       @cards = []
       @push_list.cards.each { |card| @cards << card }
       @additional_lists.each { |list| list.cards.each { |card| @cards << card } } unless @additional_lists.empty?
     end
  end
end
