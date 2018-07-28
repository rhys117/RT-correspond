class SendEnquiryUpdate < AutoManage

  OPEN_WORK_TICKETS_QUERY = ""

  ACCEPTED_NBN_CODES = []

  def initialize
    @work_tickets = RT.ticket_numbers_from_search(OPEN_WORK_TICKETS_QUERY)
    @message_email = nil
    @message_sms = nil
  end

  def all_updates!
    results = {}
    results[:sent_resolved_message] = []
    results[:sent_booked_appointment] = []
    results[:needs_your_attention] = []

    @work_tickets.each do |number|
      work = Ticket.new(number)

      latest_update = work.latest_update_item
      if update_from_nbn?(latest_update)
        result = check_nbn_update_and_send!(work)
        if result
          results[result[0]] << result[1]
        else
          results[:needs_your_attention] << work.number
        end
      else
        results[:needs_your_attention] << work.number
      end
    end

    puts "Work tickets:"
    display_results(results)
    puts ''
    results
  end

  private

    def check_nbn_update_and_send!(work)
      return nil if enquiry_updated?(work)
      content = work.history_item_content(work.latest_update_item[0])

      if nbn_reported_resolved?(content)
        # will return enquiry number or nil if did not successfully send
        enquiry_sent_number = send_resolved_message!(work)
        if enquiry_sent_number
          return [:sent_resolved_message, enquiry_sent_number]
        end
      elsif nbn_appointment_booked?(content)
        # will return enquiry number or nil if did not successfully send
        enquiry_sent_number = send_booked_appointment!(work, content)
        if enquiry_sent_number
          return [:sent_booked_appointment, enquiry_sent_number]
        end
      end
      nil
    end

    def appointment_substitutes(work_content)
      changes = {}
      datetime = work_content.match(/(?<= slot: )(.*)(?= Location )/).to_s
      changes["DATETIME"] = datetime
      changes
    end

    def send_resolved_message!(work)
      enquiry = Ticket.new(work.links[:dependedonby][0])
      @message_email = asset_file('resolved_message_email.txt')
      @message_sms = asset_file('resolved_message_sms.txt')

      message_substitutes = {}
      if enquiry.correspond!(message_personalized(enquiry, message_substitutes))
        work.comment!("auto - customer informed")
        work.status = 'resolved'
        work.save!
        enquiry.number
      else
        nil
      end
    end

    def send_booked_appointment!(work, work_content)
      enquiry = Ticket.new(work.links[:dependedonby][0])
      if work.subject.downcase.include?('ltss')
        @message_email = asset_file('booked_appointment_lts_email.txt')
        @message_sms = asset_file('booked_appointment_lts_sms.txt')
        message_substitutes = {}
      else
        @message_email = asset_file('booked_appointment_email.txt')
        @message_sms = asset_file('booked_appointment_sms.txt')
        message_substitutes = appointment_substitutes(work_content)
      end

      if enquiry.correspond!(message_personalized(enquiry, message_substitutes))
        work.comment!("auto - customer informed")
        work.status = 'stalled'
        work.save!
        enquiry.number
      else
        nil
      end
    end

    def update_from_nbn?(update_item)
      update_item[1].include?('created by noreply@nbnco.com.au')
    end

    def nbn_reported_resolved?(content)
      content.include?('Resolved Resolution code') &&
      ACCEPTED_NBN_CODES.any? { |code| content.include?(code) }
    end

    def nbn_appointment_booked?(content)
      latest_update = content.split('Appointment history')[0]
      latest_update.include?('Reason code: BOOKED - The reserved appointment has been confirmed by NBN Co and is now booked.')
    end

end