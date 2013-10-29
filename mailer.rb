require 'csv'
require 'ostruct'
require 'erb'
require 'json'
require 'highline/import'
require 'mail'

csv_file = ARGV[0]
senders_path = ARGV[1]
mail_templates_path = ARGV[2]

puts "Using CSV file #{csv_file}"
puts "Using senders #{senders_path}"
puts "Using mail templates #{mail_templates_path}"

senders = JSON.parse(File.read(senders_path))["senders"]
templates = JSON.parse(File.read(mail_templates_path))["templates"]

puts ""
senders.each do |sender|
  next if sender['password'] && !sender['password'].empty?
  pass = ask("Enter GMail password for #{sender['email']}") { |q| q.echo = false }
  sender['password'] = pass
end

def parse_row(row)
  OpenStruct.new({
    first_name: row[1],
    last_name: row[2],
    email: row[3]
  })
end

class Mailer

  def initialize(sender, receiver, template, dry = true)
    @sender = sender
    @receiver = receiver  
    @template = ERB.new(template['text'])
    @subject = template['subject']
    @dry = dry
  end

  def mail_body
    @template.result(binding)
  end

  def send!
    mail = Mail.new
    mail.body = mail_body
    mail.subject = @subject
    mail.from = @sender.email
    mail.to = @receiver.email
    mail.delivery_method(:smtp, options)
    if @dry
      puts mail
    else
      mail.deliver!
    end
  end

  def options
    { 
      address: "smtp.gmail.com",
      port: 587,
      domain: 'sk8trakr.com',
      user_name: @sender.email,
      password: @sender.password,
      authentication: 'plain',
      enable_starttls_auto: true  
    }
  end
  
end

readline
if ENV['MAILER_DRY'] == 'false'
  puts "SENDING REAL EMAILS 5 seconds to cancel"
  sleep(5)
else
  dry = true
end

set_mails_path = './sent_mails.txt'
sent_mails = File.exist?(set_mails_path) ? Set.new(File.readlines(set_mails_path).map(&:strip)) : Set.new
sent_mails_file = File.open(set_mails_path, 'a')


skipped = 0
error = 0
success = 0
CSV.foreach(csv_file) do |row|
  begin
    receiver = parse_row(row)
    if sent_mails.include?(receiver.email)
      puts "Skipping mail #{receiver.email}"
      skipped += 1
      next
    end
    sender = OpenStruct.new(senders.sample)
    mailer = Mailer.new(sender, receiver, templates.sample, dry)
    mailer.send!
    sent_mails_file.puts(receiver.email)
    success += 1
    time = rand(30..90)
    puts "Sending next mail in #{time} seconds"
    sleep(time)
  rescue
    puts "Error sending email to #{receiver.email}"
    error += 1
  end
end

puts ""
puts "Skipped emails #{skipped}"
puts "Error emails #{error}"
puts "Sucessfull emails #{success}"