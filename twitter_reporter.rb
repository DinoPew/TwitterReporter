#!/usr/bin/env ruby

require 'selenium-webdriver'
require 'highline/import'
require 'open-uri'
require 'openssl'
require 'choice'
require 'fileutils'
require 'logger'
require 'active_support/core_ext/array/grouping'

# The reporter class
class TwitterReporter

  # Get the username from cmdline switch or prompt the user
  def get_username(choice_user)
    if choice_user == nil
      puts "Enter Username: "
      gets.chomp
    else
      choice_user.strip
    end
  end

  # Prompt for password
  def get_password(prompt="Enter Password: ")
    ask(prompt) { |q| q.echo = false }
  end

  # Run the reporter
  def run (username, password, file_contents, logger, reported, suspended, error)
    logger.info "Opening FireFox, Please Wait..."
    # Init WebDriver
    browser = Selenium::WebDriver.for :firefox
    # Go to twitter
    browser.navigate.to "https://www.twitter.com"
    # Fill in username
    username_field = browser.find_element(:id, 'signin-email')
    username_field.send_keys username
    # Fill in password
    passwd_field = browser.find_element(:id, 'signin-password')
    passwd_field.send_keys password
    # Submit login form
    passwd_field.submit
    # Loop over our targets
    file_contents.each do |line|
      # Clean the target string
      line = line.strip
      # Get the target ID
      id = line.split('=')[1]
      # Start a rescue block
      begin
        # Navigate to the targets page
        browser.navigate.to line
        # Is the target suspended?
        if browser.current_url == 'https://twitter.com/account/suspended'
          # notify suspension
          logger.warn id + ' - Suspended'
          # Log suspension
          suspended.warn id
        else
          # Go to their profile page
          browser.find_element(:xpath, "//*[@id='ft']/a").click
          # Drop down
          browser.find_element(:css, '.user-dropdown').click
          # Click report
          browser.find_element(:css, 'li.report-text button[type="button"]').click
          sleep(3)
          # Click next
          browser.find_element(:xpath, "//button[@class='btn primary-btn new-report-flow-next-button']").click
          sleep(2)
          # Click done
          browser.find_element(:xpath, "//button[@class='btn primary-btn new-report-flow-done-button']").click
          # Output the ID
          logger.info id + ' - Reported'
          # Log the ID
          reported.info id
        end
      rescue
        # an error happened so notify
        logger.error id + ' - Error'
        # log the error
        error.error id
      end
    end
  end
end

# Configure commandline switches
Choice.options do
  header ''
  header 'Options:'

  option :username do
    short '-u'
    long '--username=USERNAME'
    desc 'The username for your Twitter account, you will be prompted if you do not define it.'
    default nil
  end

  option :file_path do
    short '-f'
    long '--file_path=FILE_PATH'
    desc 'Path to target file. Can be local file or a url to plain text file. (default: https://ghostbin.com/paste/fgrfx/raw)'
    default 'https://ghostbin.com/paste/fgrfx/raw'
  end

  option :threads do
    short '-t'
    long '--threads=THREADS'
    desc 'The number of threads to run. This will open multiple browser windows.'
    default 1
  end

  option :help do
    short '-h'
    long '--help'
    desc 'Show this message'
  end
end

# Create Log dir
FileUtils.mkdir_p(File.expand_path File.dirname(__FILE__)+'/log')
# Init loggers
logger = Logger.new(STDOUT)
reported = Logger.new(File.expand_path File.dirname(__FILE__)+'/log/reported-'+Time.now.to_i.to_s+'.log')
suspended = Logger.new(File.expand_path File.dirname(__FILE__)+'/log/suspended-'+Time.now.to_i.to_s+'.log')
error = Logger.new(File.expand_path File.dirname(__FILE__)+'/log/error-'+Time.now.to_i.to_s+'.log')
# Set log levels
logger.level = Logger::INFO
reported.level = Logger::INFO
suspended.level = Logger::INFO
error.level = Logger::INFO


# We need to disable SSL verification for windows, unless you install this cert: http://curl.haxx.se/ca/cacert.pem
# If you install that cert you should comment the next 7 lines out
if Gem.win_platform? && Choice[:file_path] =~ /\A#{URI::regexp(['http', 'https'])}\z/
  logger.warn 'Running on Windows... We need to disable ssl to download our targets.'
  original_verbosity = $VERBOSE
  $VERBOSE = nil
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  $VERBOSE = original_verbosity
end


# Make sure that threads are an int
if Choice[:threads].to_s.strip.to_i.is_a? Integer
# Init our twitter reporter class
  tr = TwitterReporter.new
# Get Twitter account info
  uname = tr.get_username(Choice[:username])
  passwd = tr.get_password
# Get our targets from the specified path and return the contents
  threads = []
  logger.info 'Gathering Targets...'
  open(Choice[:file_path]) { |f| f.read }.split("\n").to_ary.in_groups(Choice[:threads].strip.to_i, false).each do |chunk|
    # create our threads
    threads << Thread.new {
      logger.info 'Starting new thread...'
      # Run it
      tr.run(uname, passwd, chunk, logger, reported, suspended, error)
    }
  end
# Fire up the threads
  threads.each { |thr| thr.join }
else
  logger.error 'Thread value must be an Integer'
end