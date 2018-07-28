# Request tracker scripts
Collection of useful scripts for workflow involving Request Tracker. 

# Request Tracker Mass Ticket Correspondence Script
This scripts aim is to provide an easy solution to deliver the same correspondence to multiple tickets at once.

# Prerequisites
## Ruby must be installed
If necessary download and install from:
https://www.ruby-lang.org/en/downloads/
note: ruby is pre-installed on macOS but not Windows

## Gem 'rt-client' must be installed
Can be installed from terminal or command line with the following command once ruby has been installed: gem install rt-client

# Usage
## Set user credentials and server location
You should set your server, username and password to the corresponding variables in a user.yml file in teh lib directory. Alternatively if not set supplied you will be prompted when running the script.
### lib/user.yml example
```
server: http://rt.example.com
username: your_rt_username
password: your_rt_password
```

The message you want to send should be in the assets directory as a message.txt file.
### assets/message.txt example
```
Hi!

Include your message here.

Regards,
Rhys.
```

Include tickets that should be sent correspondence in the assets directory in a tickets.txt file, each ticket should be separated by a comma (,)
### assets/tickets.txt example
```
31234, 41231, 53244, 90123
```

Run the script from terminal or command prompt with: ruby message_tickets.rb and follow the prompts