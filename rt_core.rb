require "rt_client"
require "yaml"
require 'fileutils'
require 'pry'
require_relative 'string_colors'

def delete_cookies
  FileUtils.rm_rf('cookies')
  FileUtils.mkdir('cookies')
end

def ensure_have_user_login(file_data)
  USER_INFO.each do |info|
    loop do
      break unless blank_string?(file_data[info])
      puts "Please provide #{info}: "
      puts "eg http://rt.example.com" if info == 'server'
      file_data[info] = gets.chomp
    end
  end
  file_data
end

def blank_string?(string)
  return true if string.nil?
  string.strip.length == 0
end

class RT_Client

  def add_link(field_hash)
    if field_hash.has_key? :id
      id = field_hash[:id]
    else
      raise "RT_Client.add_link requires a user or ticket id in the 'id' key."
    end
    type = "ticket"
    sid = id
    if id =~ /(\w+)\/(.+)/
      type = $~[1]
      sid = $~[2]
    end
    payload = compose(field_hash)
    resp = @site["#{type}/#{sid}/links"].post payload
    resp
  end

  def merge(field_hash)
    if field_hash.has_key? :id
      id = field_hash[:id]
    else
      raise "RT_Client.merge requires a user or ticket id in the 'id' key."
    end
    if field_hash.has_key? :into_id
      into = field_hash[:into_id]
    else
      raise "RT_Client.merge requires a ticket id in the 'into_id' key."
    end
    type = "ticket"
    sid = id
    if id =~ /(\w+)\/(.+)/
      type = $~[1]
      sid = $~[2]
    end
    payload = compose(field_hash)
    resp = @site["#{type}/#{sid}/merge/#{into}"].post payload
    resp
  end

end

class Ticket

  attr_reader :number
  attr_accessor :owner, :status

  def initialize(num, rt)
    set_params(num, rt)
  end

  def correspond!(msg)
    response = RT.correspond( :id   => @number,
                              :Text => msg )
    display_correspondance_response(response)
  end

  def merge_into!(ticket)
    RT.add_link( :id      => @number,
                 :into_id => ticket )
  end

  def save!
    RT.edit( :id      => @number,
             :status  => @status,
             :owner   => @owner )
  end

  private

    def set_params(num, rt)
      @number = num

      response = RT.show(@number)
      @owner = response['owner'].to_s
      @status = response['status'].to_s
    end

    def display_correspondance_response(response)
      if response.to_s.downcase.include?('credentials required')
        puts "Incorrect Credentials".red
        exit
      elsif response.to_s.downcase.include?('message recorded')
        puts "#{@number}: #{response}".green
      elsif response.to_s.downcase.include?('correspondence added')
        puts "#{@number}: #{response}".green
      else
        puts "#{@number}: #{response}".pink
      end
    end
end

delete_cookies

user_file_data = YAML.load_file('user.yml')
USER_INFO = ['server', 'username', 'password']
USER = ensure_have_user_login(user_file_data)

RT = RT_Client.new( :server  => USER['server'],
                    :user    => USER['username'],
                    :pass    => USER['password'],
                    :cookies => 'cookies' )