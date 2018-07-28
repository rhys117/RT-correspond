class CloseAfterWarning < AutoManage

  def initialize
    @two_day_warning_tickets = asset_file('auto_manage.yml')['two_days']
  end

  def two_days!
    results = {}
    results[:resolved] = []
    results[:already_resolved] = []
    results[:resolving_failed] = []
    results[:needs_your_attention] = []

    @two_day_warning_tickets.each do |ticket_number|
      enquiry = Ticket.new(ticket_number)

      if enquiry.status == 'resolved'
        results[:already_resolved] << enquiry.number
        next
      end

      if enquiry.owner == USER['username'] && no_response_to_warning?(enquiry)
        enquiry.status = 'resolved'
        if enquiry.save!
          results[:resolved] << enquiry.number
        else
          results[:resolving_failed] << enquiry.number
        end
      else
        results[:needs_your_attention] << enquiry.number
      end
    end
    puts "Two Day Warnings:"
    display_results(results)
    puts '---------------------------'
    results
  end

  private

    def no_response_to_warning?(ticket)
      # ensures ticket not updated in past two days and status is waiting
      unless ticket.last_updated.to_date <= Date.today - 2 &&
             ticket.status == 'waiting'
        return false
      end

      last_correspondence = ticket.correspondance_history.last
      last_correspondence_item = ticket.history_item_info(last_correspondence[0])
      last_correspondence_content = last_correspondence_item["content"].to_s
      last_correspondence_sent_by = last_correspondence_item["creator"]

      # ensures last correspondence was two day close warning or resolved
      match_phrases = []
      match_phrases << 'this ticket is due to be closed in two days'
      match_phrases << 'we believe the problem you were suffering from has now been resolved'
      match_phrases << "please reply with callback support"
      match_phrases << 'if you are still experiencing problems please restart your equipment and test again'
      match_phrases << 'if you are still in need of assistance please respond to this email or call us on'

      received_warning = false
      match_phrases.each do |phrase|
        received_warning = true if last_correspondence_content.downcase.include?(phrase)
      end

      unless received_warning && last_correspondence_sent_by == USER['username']
        return false
      end

      # ensures no comments made to ticket since two day warning sent
      return false unless ticket.latest_update_item == last_correspondence
      true
    end

end