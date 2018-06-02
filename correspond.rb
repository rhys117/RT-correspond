require_relative 'rt_core'

class MessageTickets

  def initialize
    get_contents_of_files
  end

  def send_all
    if blank_string?(@message)
      puts "Message cannot be empty. Please provide correspondence in message.txt".red
      exit
    end

    @status = get_new_status
    if @status == 'resolved'
      @owner = 'Nobody'
      puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
    else
      @owner_change = change_ticket_owner?
    end
    exit unless messaging_details_correct?
    post_correspondance
  end

  private

    def post_correspondance
      @tickets.each do |num|
        current = Ticket.new(num, RT)
        current.correspond!(@message)
        current.status = @status
        current.owner = USER[:username] if @owner_change
        current.owner = 'Nobody' if @status == 'resolved'
        current.save!
      end
    end

    def get_contents_of_files
      @message = File.read('message.txt')
      @tickets = File.read('tickets.txt').split(',').map(&:strip).map(&:to_i)
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
        break if accepted_answers.include?(@owner_change)
        puts "Should the ownership of the ticket change to you?"
        puts "(Y)es or (N)o"
        @owner_change = gets.chomp.downcase
      end
      owner_change == 'y'
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

    def display_empty_message
      puts "Must provide message in message.txt file in scripts directory".red
    end

    def messaging_details_correct?
      check_answer = nil
      accepted_answers = ['y', 'q']
      loop do
        break if accepted_answers.include?(check_answer)
        puts ''
        puts "Please check the following".red
        print "Tickets that will be sent correspondence: ".green
        puts "#{@tickets.join(', ')}"
        puts "Correspondence: ".green
        puts "#{@message}"
        print "Ticket status: ".green
        puts "#{@status}"
        if @status == 'resolved'
          puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
        elsif @owner_change
          print "Change owner to you?:".green
          puts" Yes"
        else
          print "Change owner to you?:".green
          puts" No"
        end

        puts "Is this correct? (Y)es or (Q)uit".red
        check_answer = gets.chomp.downcase
      end
      check_answer == 'y'
    end
end

MessageTickets.new.send_all
delete_cookies