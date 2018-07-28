require "rt_client"
require "yaml"
require 'fileutils'
require 'Date'
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

def asset_file(file_string)
  split_type = file_string.split('.')

  case split_type[1]
  when 'txt'
    File.read("assets/#{file_string}")
  when 'yml'
    YAML.load_file("assets/#{file_string}")
  else
    false
  end
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

  def search(*params)
    query = params[0]
    order = ""
    if params.size > 1
      order = params[1]
    end
    if params[0].class == Hash
      params = params[0]
      query = params[:query] if params.has_key? :query
      order = params[:order] if params.has_key? :order
    end
    reply = []
    resp = @site["search/ticket/?query=#{URI.escape(query)}&orderby=#{order}&format=s"].get
    raise "Invalid query (#{query})" if resp =~ /Invalid query/
    resp = resp.split("\n") # convert to array of lines
    resp.each do |line|
      f = line.match(/^(\d+):\s*(.*)/)
      #reply[f[1].to_s] = f[2].to_s if f.class == MatchData
      reply.push [f[1].to_s.to_i, f[2].to_s] if f.class == MatchData
    end
    reply
  end

  def ticket_numbers_from_search(query)
    RT.search( :query => query ).map { |result| result[0].to_i }
  end

end

class Ticket

  attr_reader :number, :links, :requestors, :classification
  attr_accessor :owner, :status, :subject

  def initialize(num)
    set_params(num)
  end

  def correspond!(msg)
    response = RT.correspond( :id   => @number,
                              :Text => msg )
    display_correspondance_response(response)
    if response.to_s.downcase.include?('200 ok')
      @status = 'open'
      return true
    else
      false
    end
  end

  def merge_into!(ticket)
    RT.merge( :id      => @number,
              :into_id => ticket.number )
  end

  def save!
    response = RT.edit( :id      => @number,
                        :status  => @status,
                        :owner   => @owner )
    unless response.to_s.downcase.include?('200 ok')
      puts "Error: unable to save".red
      puts response.red
      return false
    end
    true
  end

  def comment!(comment)
    RT.comment( :id   => @number,
                :Text => comment )
  end

  def history
    response = RT.history( :id => @number,
                           :comments => true)
    response.map { |obj_array| [obj_array[0].to_s.to_i, obj_array[1].to_s.strip] }
  end

  def history_item_info(history_id)
    RT.history_item(@number, history_id)
  end

  def history_item_content(history_id)
    history_item_info(history_id)["content"].to_s
  end

  def correspondance_history
    history.select { |hist_array| hist_array[1].downcase.include?('correspondence') }
  end

  def comments_history
    history.select { |hist_array| hist_array[1].downcase.include?('comments') }
  end

  def latest_update_item
    history.select do |hist_array|
      hist_array[1].downcase.include?('comments') ||
      hist_array[1].downcase.include?('correspondence') ||
      hist_array[1].downcase.include?('created by noreply@nbnco.com.au')
    end.last
  end

  def nbn_responses
    history.select do |hist_array|
      hist_array[1].downcase.include?('created by noreply@nbnco.com.au')
    end
  end

  def last_updated
    DateTime.parse(history_item_info(history.last[0])["created"])
  end

  def to_s
    "#{@number}"
  end

  private

    def set_params(num)
      @number = num

      response = RT.show(@number)
      @owner = response['owner'].to_s
      @status = response['status'].to_s
      @subject = response['subject'].to_s
      @requestors = response['requestors'].to_s.split(', ')
      @classification = response['cf.{classification}'].to_s

      @links = get_links
      # SkyMesh specific
      @entityid = determine_entityid
    end

    # SkyMesh specific
    def determine_entityid
      enitities = @subject.scan(/\[(.*?)\]/)
      enitities.empty? ? nil : enitities.flatten[0].split('/')[0]
    end

    def get_links
      converted = {}
      RT.links(id: @number).each do |ob_fields, ob_tickets|
        converted[ob_fields.to_sym] = ob_tickets.to_s.scan(/\d+/).map(&:to_i)
      end

      # SkyMesh specific
      converted.each do |field, tickets_array|
        converted[field] = tickets_array.reject { |ticket| ticket.digits.count < 7 }
      end
      converted.reject! { |id, _| id == :id }
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

user_file_data = YAML.load_file('lib/user.yml')
USER_INFO = ['server', 'username', 'password']
USER = ensure_have_user_login(user_file_data)

RT = RT_Client.new( :server  => USER['server'],
                    :user    => USER['username'],
                    :pass    => USER['password'],
                    :cookies => 'cookies' )

at_exit do
  delete_cookies
end