require_relative 'lib/rt_core'
require 'pry'

def add_sms_requester(ticket, mobile)
  RT.add_watcher(ticket, "#{mobile}@sms.skymesh.net.au", "Requestors")
end

binding.pry