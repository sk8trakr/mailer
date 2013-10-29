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

if ENV['MAILER_DRY'] == 'false'
  puts "Do you realy want to send real mails? Enter 'y' for yes"
  dry = readline.strip.downcase == 'y'
else
  dry = true
end


CSV.foreach(ARGV[0]) do |row|
  receiver = parse_row(row)
  sender = OpenStruct.new(senders.sample)
  mailer = Mailer.new(sender, receiver, templates.sample, dry)
  mailer.send!
end