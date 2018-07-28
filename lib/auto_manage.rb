class AutoManage

  private

    def enquiry_updated?(work)
      links = work.links[:dependedonby]
      # Checks only depended on by one tickets
      return true if links.size > 1
      enquiry = Ticket.new(links[0])
      enquiry.last_updated > work.last_updated
    end

    def display_results(results)
      results.each do |description, ticket_numbers|
        line_title = description.to_s.gsub('_', ' ').capitalize
        puts "  #{line_title}: #{ticket_numbers.join(', ')}"
      end
    end

    def send_via_sms?(enquiry)
      send_via_sms = enquiry.requestors.any? do |requestor|
        requestor.include?('sms.skymesh')
      end
    end

    def message_personalized(enquiry, message_substitutes)
      message = send_via_sms?(enquiry) ? @message_sms : @message_email
      message = message.dup
      message_substitutes.each { |key, value| message.gsub!("{#{key}}", value.to_s) }
      message.gsub!('{AGENT}', USER['username'].split('.').first.capitalize)
      message
    end

end
