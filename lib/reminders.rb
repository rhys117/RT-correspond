class Reminders

  ENQURY_TICKETS_QUERY = ""

  EVERYONES_ENQURY_TICKETS_QUERY = ""

  attr_reader :open_reminders

  def initialize
    @open_reminders = RT.ticket_numbers_from_search(REMINDERS_QUERY)
  end

  def delete_if_case_resolved!
    results = {}
    results[:resolved] = []
    results[:not_owner] = []
    results[:current_cases] = []

    @open_reminders.each do |number|
      reminder = Ticket.new(number)

      case_number = reminder.links[:refersto][0]
      current = Ticket.new(case_number.to_i)

      if current.status.downcase == 'resolved'
        results[:resolved] << "##{current.number}: #{current.subject}"
        reminder.status = 'resolved'
        reminder.save!
      elsif current.owner != USER['username']
        results[:not_owner] << "##{current.number}: #{current.subject}"
      else
        results[:current_cases] << "##{current.number}: #{current.subject}"
      end
    end

    display_results(results)
    results
  end

  def enquiry_cases_without
    results = []
    enquiry_tickets = RT.ticket_numbers_from_search(ENQURY_TICKETS_QUERY)

    enquiry_tickets.each do |enquiry_number|
      enquiry = Ticket.new(enquiry_number)

      if enquiry.links[:referredtoby].nil?
        results << enquiry.number
        next
      end

      reminders = related_reminders(enquiry)
      results << enquiry.number if reminders.empty?
    end

    print "Tickets missing reminders: ".red
    puts results.join(', ')
    results
  end

  def everyones_enquiry_cases_without
    reminders = RT.ticket_numbers_from_search( :query => EVERYONES_REMINDERS_QUERY )
    enquiry_tickets = RT.ticket_numbers_from_search( :query => EVERYONES_ENQURY_TICKETS_QUERY )

    results = {}

    enquiry_tickets.each do |enquiry_number|
      enquiry = Ticket.new(enquiry_number)
      results[enquiry.owner] = [] if results[enquiry.owner].nil?

      if enquiry.links[:referredtoby].nil?
        results[enquiry.owner] << enquiry.number
        next
      end

      reminders = related_reminders(enquiry)
      results[enquiry.owner] << enquiry.number if reminders.empty?
    end

    print "Tickets missing reminders:".red
    results.each do |person, tickets_array|
      puts "  #{person}: #{tickets_array.join(', ')}"
    end
    results
  end

  private

    def related_reminders(enquiry)
      reminders = enquiry.links[:referredtoby] & @open_reminders
      reminders.each do |reminder_number|
        reminder = Ticket.new(reminder_number)
        reminders.delete(reminder.number) if reminder.status == 'resolved'
      end
      reminders
    end

    def display_results(results)
      puts "Reminders for current cases:".green
      results[:current_cases].each do |result|
        puts "  #{result}"
      end
      puts ''
      puts "Deleted reminders of resolved cases:".red
      results[:resolved].each do |result|
        puts "  #{result}"
      end
      puts ''
      puts "Cases which you are not the ticket owner:".yellow
      results[:not_owner].each do |result|
        puts "  #{result}"
      end
      puts ''
    end

end
