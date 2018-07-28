require_relative 'lib/rt_core'

class MatchAndMerge

  attr_accessor :query, :subject_condition, :field_in_existing

  def initialize(query, subject_condition, field_in_existing)
    set_params(query, subject_condition, field_in_existing)
  end

  def merge_all!
    @tickets = RT.search( :query => @query )
    puts "No results found based on query." if @tickets.empty?

    tickets_with_converted_subjects = convert_subjects_match_results
    tickets_with_converted_subjects.each do |ticket_id, match_term|
      current = Ticket.new(ticket_id)

      custom_field_match = RT.search( :query => "#{@field_in_existing} = #{match_term}}" )
      if custom_field_match.empty?
        puts "#{current}: Could not find match.".red
      else
        existing_case = Ticket.new(custom_field_match[0][0])
        response = current.merge_into!(existing_case)

        if response.to_s.downcase.include?('merge completed')
          puts "#{current}: Merged into #{existing_case}".green
          puts response.green
          existing_case.status = 'open'
          existing_case.save!
        else
          puts "#{current}: Unsuccessful".red
          puts response.red
        end
      end
    end
  end

  private

    def set_params(query, subject_condition, field_in_existing)
      @query = query
      @subject_condition = subject_condition
      @field_in_existing = field_in_existing
    end

    def convert_subjects_match_results
      results = {}
      @tickets.each do |array|
        results[array[0]] = subject_condition.call(array[1])
      end
      results
    end
end

query = "Queue = Example"
subject_condition = lambda { |subject| subject.scan(/\d+/).first }
field_in_existing = "Example"

MatchAndMerge.new(query, subject_condition, field_in_existing).merge_all!