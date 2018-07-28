class SendWarning < AutoManage

  def initialize
    @check_contact_tickets = asset_file('auto_manage.yml')['check_contact']
    @message_email = asset_file('two_day_warning_email.txt')
    @message_sms = asset_file('two_day_warning_sms.txt')
  end

  def no_contact!
    results = {}
    results[:sent_warning_message] = []
    results[:needs_your_attention] = []
    results[:case_already_resolved] = []

    @check_contact_tickets.each do |ticket_number|
      enquiry = Ticket.new(ticket_number)

      if enquiry.status == 'resolved'
        results[:case_already_resolved] << enquiry.number
        next
      end

      if enquiry.owner == USER['username'] && no_customer_contact?(enquiry)
        message_substitutes = no_contact_substitutes(enquiry)

        if enquiry.correspond!(message_personalized(enquiry, message_substitutes))
          results[:sent_warning_message] << enquiry.number
          enquiry.status = 'waiting'
          enquiry.save!
        end
      else
        results[:needs_your_attention] << enquiry.number
      end
    end

    puts "Waiting on customer contact:"
    display_results(results)
    puts '---------------------------'
    results
  end

  private

    def no_customer_contact?(ticket)
      # ensures ticket not updated in past five days and status is waiting and
      # ensures last comment or correspondance was from username
      ticket.last_updated.to_date <= Date.today - 5 && ticket.status == 'waiting' &&
      (ticket.latest_update_item[1].include?(USER['username']) || 
      ticket.latest_update_item[1].include?('Ticket created by SAMS'))
    end

    def no_contact_substitutes(enquiry)
      changes = {}
      changes["TICKET"] = enquiry.number
      changes["CLASSIFICATION"] = if enquiry.classification.empty?
                                    ""
                                  else
                                    classification = enquiry.classification.split('-').first
                                    "- #{classification}"
                                  end
      changes
    end

end