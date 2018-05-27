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
You should set your server, username and password to the corresponding variables in user.yml. Alternatively if not set supplied you will be prompted when running the script.
### user.yml example
```
server: http://rt.example.com
username: your_rt_username
password: your_rt_password
```
## Set message to be sent in message.txt file in same directory as correspond.rb script

## Include tickets that should be sent correspondence in tickets.txt separated by a comma (,) in same directory as correspond.rb script
e.g 31234, 41231, 53244, 90123

# Run the script from terminal or command prompt with: ruby oop_correspond.rb
## Follow the prompts