require "rt_client"
require "yaml"
require 'fileutils'
require 'pry'
require_relative 'string_colors'

module DisplayUI
  def display_empty_message
    puts "Must provide message in message.txt file in scripts directory".red
  end

  def get_status_answer
    ticket_status = nil
    accepted_answers = ['s', 'w', 'o', 'r']
    loop do
      break if accepted_answers.include?(ticket_status)
      puts "What status should tickets be set to once message is sent"
      puts "(S)talled, (W)aiting, (O)pen, or (R)esolved"
      ticket_status = gets.chomp.downcase
    end
    return ticket_status
  end

  def messaging_details_correct?(tickets, message, status, owner)
    check_answer = nil
    accepted_answers = ['y', 'q']
    loop do
      break if accepted_answers.include?(check_answer)
      puts ''
      puts "Please check the following".red
      print "Tickets that will be sent correspondence: ".green
      puts "#{tickets.join(', ')}"
      print "Correspondence: ".green
      puts "#{message}"
      print "Ticket status: ".green
      puts "#{status}"
      if @owner == 'Nobody'
        puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
      end
      print "Change owner to you?:".green unless @owner == 'Nobody'
      puts" #{@owner.upcase}" unless @owner == 'Nobody'
      puts "Is this correct? (Y)es or (Q)uit".red
      check_answer = gets.chomp.downcase
    end
    check_answer == 'y'
  end

  def display_correspondance_response(number, response)
    if response.to_s.downcase.include?('credentials required')
      puts "Incorrect Credentials".red
      exit
    elsif response.to_s.downcase.include?('message recorded')
      puts "#{number}: #{response}".green
    elsif response.to_s.downcase.include?('correspondence added')
      puts "#{number}: #{response}".green
    else
      puts "#{number}: #{response}".pink
    end
  end
end

class Ticket
  include DisplayUI

  attr_reader :number
  attr_accessor :owner, :status

  def initialize(num, rt)
    set_params(num, rt)
  end

  def correspond!(msg)
    response = @rt.correspond( :id   => @number,
                              :Text => msg )
    display_correspondance_response(@number, response)
  end

  def save!
    @rt.edit( :id      => @number,
             :status  => @status,
             :owner   => @owner )
  end

    private

    def set_params(num, rt)
      @number = num
      @rt = rt

      response = @rt.show(@number)
      @owner = response['owner'].to_s
      @status = response['status'].to_s
    end
end

class MessageTickets
  include DisplayUI

  USER_INFO = ['server', 'username', 'password']

  def initialize
    delete_cookies
    get_contents_of_files
    login_to_rt
  end

  def send_all
    @status = get_new_status
    if @status == 'resolved'
      @owner = 'Nobody'
      puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
    else
      @owner = @user['username'] if change_ticket_owner?
    end
    exit unless messaging_details_correct?(@tickets, @message, @status, @owner)
    post_correspondance
  end

    private

    def delete_cookies
      FileUtils.rm_rf('cookies')
      FileUtils.mkdir('cookies')
    end

    def blank_string?(string)
      return true if string.nil?
      string.strip.length == 0
    end

    def post_correspondance
      @tickets.each do |num|
        current = Ticket.new(num, @rt)
        current.correspond!(@message)
        current.status = @status
        current.owner = @owner
        current.save!
      end
    end

    def get_contents_of_files
      @user = YAML.load_file('user.yml')
      @message = File.read('message.txt')
      @tickets = File.read('tickets.txt').split(',').map(&:strip).map(&:to_i)
    end

    def ensure_have_user_login
      USER_INFO.each do |info|
        loop do
          break unless blank_string?(@user[info])
          puts "Please provide #{info}: "
          puts "eg http://rt.example.com" if info == 'server'
          @user[info] = gets.chomp
        end
      end
    end

    def login_to_rt
      ensure_have_user_login

      @rt = RT_Client.new( :server  => @user['server'],
                          :user    => @user['username'],
                          :pass    => @user['password'],
                          :cookies => 'cookies' )
    end

    def get_new_status
      case get_status_answer
      when 's'
        'stalled'
      when 'w'
        'waiting'
      when 'o'
        'open'
      when 'r'
        'resolved'
      end
    end

    def change_ticket_owner?
      owner_change = nil
      accepted_answers = ['y', 'n']
      loop do
        break if accepted_answers.include?(owner_change)
        puts "Should the ownership of the ticket change to you?"
        puts "(Y)es or (N)o"
        owner_change = gets.chomp.downcase
      end
      owner_change == 'y'
    end
end

message = MessageTickets.new.send_all