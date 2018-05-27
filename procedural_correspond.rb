require "rt_client"
require "yaml"
require 'fileutils'
require_relative 'string_colors'

def empty?(string)
  return true if string.nil?
  string.strip.length == 0
end

# Ensure no cookies present by deleting directoy and making it again otherwise messages can be sent with old user cookie
FileUtils.rm_rf('cookies')
FileUtils.mkdir('cookies')

# Load user credentials
user = YAML.load_file('user.yml')

# Load message to send
message = File.read('message.txt')

# Ensure have all user data else prompt user
USER_INFO = ['server', 'username', 'password']
  USER_INFO.each do |info|
  loop do
    break unless empty?(user[info])
    puts "Please provide #{info}:"
    puts "eg http://rt.example.com" if info == 'server'
    user[info] = gets.chomp
  end
end

# Ensure message not empty or prompt user and exit
if empty?(message)
  puts "Must provide message in message.txt file in scripts directory".red
  exit
end

# Check with user what the status of the ticket should be set to
ticket_status = nil
accepted_answers = ['s', 'w', 'o', 'r']
loop do
  break if accepted_answers.include?(ticket_status)
  puts "What status should tickets be set to once message is sent"
  puts "(S)talled, (W)aiting, (O)pen, or (R)esolved"
  ticket_status = gets.chomp.downcase
end

ticket_status = case ticket_status
                when 's'
                  'stalled'
                when 'w'
                  'waiting'
                when 'o'
                  'open'
                when 'r'
                  'resolved'
                end

# If ticket status is being set to resolved change owner to Nobody else ask if ownership should change to user
owner_change = nil
if ticket_status == 'resolved'
  owner_change = 'Nobody'
  puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
else
  accepted_answers = ['y', 'n']
  loop do
    break if accepted_answers.include?(owner_change)
    puts "Should the ownership of the ticket change to you?"
    puts "(Y)es or (N)o"
    owner_change = gets.chomp.downcase
  end
end

# Load tickets to send message too
tickets = File.read('tickets.txt').split(',').map(&:strip).map(&:to_i)

# Confirm with user all gathered info is correct or quit
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
  puts "#{ticket_status}"
  if owner_change == 'Nobody'
    puts 'Warning: When resolving tickets ownership of ticket will be set to Nobody'.red
  end
  print "Change owner to you?:".green unless owner_change == 'Nobody'
  puts" #{owner_change.upcase}" unless owner_change == 'Nobody'
  puts "Is this correct? (Y)es or (Q)uit".red
  check_answer = gets.chomp.downcase
end
exit if check_answer == 'q'

# Get cookie for RT REST
rt = RT_Client.new( :server  => user['server'],
                    :user    => user['username'],
                    :pass    => user['password'],
                    :cookies  => 'cookies' )

tickets.each do |ticket_id|
  # send message and get response
  rt_response = rt.correspond( :id   => ticket_id,
                            :Text => message )
  if rt_response.to_s.downcase.include?('credentials required')
    puts "Incorrect Credentials".red
    exit
  elsif rt_response.to_s.downcase.include?('correspondence added')
    puts "#{ticket_id}: #{rt_response}".green
  # next elsif statement covers older versions of RT
  elsif rt_response.to_s.downcase.include?('message recorded')
    puts "#{ticket_id}: #{rt_response}".green
  else
    puts "#{ticket_id}: #{rt_response}".pink
  end

  # change ticket status to selected status
  rt.edit( :id      => ticket_id,
           :status  => ticket_status )

  # change ticket owner if change ownsership set to yes
  case owner_change
  when 'y'
    rt.edit( :id      => ticket_id,
             :owner   => user['username'])
  when 'Nobody'
    rt.edit( :id      => ticket_id,
             :owner   => 'Nobody')
  end
end