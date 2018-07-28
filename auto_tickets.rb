files = Dir["lib/*.rb"] # .sort_by do { |file| file.include?('auto_manage') ? 1 : -1 }
require_relative 'lib/rt_core'
require_relative 'lib/auto_manage'
files.each { |file| require_relative file }

class AutoTickets

  def complete_all_actions
    puts "#{Time.new.inspect}"
    reminders = Reminders.new
    reminders.delete_if_case_resolved!
    reminders.enquiry_cases_without

    CloseAfterWarning.new.two_days!
    SendWarning.new.no_contact!
    SendEnquiryUpdate.new.all_updates!
  end

  def all_support_cases_without_reminders
    Reminders.new.everyones_enquiry_cases_without
  end

  def auto_timed_loop
    counter = 1
    loop do
      # every 15mins check and update enquiry tickets from nbn/vocus updates
      sleep(900)
      puts "#{Time.new.inspect}"
      SendEnquiryUpdate.new.all_updates!
      # every two hours cleanup reminders
      if counter % 8 == 0
        reminders = Reminders.new
        reminders.delete_if_case_resolved!
      end
      counter += 1
    end
  end

end

manage = AutoTickets.new
manage.complete_all_actions
manage.auto_timed_loop
