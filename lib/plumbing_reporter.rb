require 'rest_client'
require 'json'
require 'sendgrid-ruby'
include SendGrid
require 'date'
require 'pry'
require 'csv'

class Callrailreports
  require_relative 'constants'

  def initialize(name, email)
    @name = name
    @email = EMAILS[@name]
    @company_id = COMPANIES[@name]
    @pay_per_lead = PAYPERLEAD[@name]
    @subject = "#{@name} PLUMBING REPORT #{Date.today - 7} to #{Date.today - 1}"
  end

  def run
    pages_of_calls

    get_calls

    calculate_total

    create_csv

    send_report
  end

  def get_calls # connect to api and get json
    over_90_calls = []
    (1..@total_pages).each do |page|
      parameters = {company_id: @company_id,
              date_range: 'last_7_days',
              answer_status: 'answered',
              first_time_callers: true,
              page: page}

      response = RestClient.get 'https://api.callrail.com/v2/a/831937628/calls.json', :authorization => "Token token=\"#{API_KEY}\"", :params => parameters

      calls = JSON.parse(response.body)['calls']

      over_90_calls += calls.select do |call|
        call['recording_duration'] > 90 unless not call['recording_duration']
      end
    end

    @call_array = over_90_calls.uniq {|call_hash| call_hash["customer_phone_number"]}
  end

  def pages_of_calls
    parameters = {company_id: @company_id,
                  date_range: 'last_7_days',
                  answer_status: 'answered',
                  first_time_callers: true}

    response = RestClient.get 'https://api.callrail.com/v2/a/831937628/calls.json', :authorization => "Token token=\"#{API_KEY}\"", :params => parameters

    @total_pages = JSON.parse(response.body)["total_pages"]
  end

  def calculate_total
    @total_pay = @call_array.size * @pay_per_lead
  end

  def create_csv # name:
    CSV.open("#{@subject}.csv", "wb") do |csv|
      csv << ['Name', 'Phone number', 'City', 'Time called', 'Duration', 'Id', 'Recording', 'Tracking phone number']
      @call_array.each do |call|
        csv << [call["customer_name"], call["customer_phone_number"], call["customer_city"], call["start_time"], call["duration"], call["id"], call["recording"], call["tracking_phone_number"]]
      end
    end
  end

  def send_report # send the report as email
    #binding.pry
    from = Email.new(email: FROM_EMAIL)
    to = Email.new(email: @email)
    subject = @subject
    content = Content.new(type: 'text/plain', value: "Report for #{Date.today - 7} \(monday\) to #{Date.today - 1} \(sunday\) is attached. The total earned is: $#{@total_pay} \(#{@call_array.size} unique 90sec+ calls * $#{@pay_per_lead}\). Please review and give me your consent via a skype message and I will send the payment per usual.")
    mail = Mail.new(from, subject, to, content)

    attachment = Attachment.new
    attachment.content = Base64.strict_encode64(File.open("#{@subject}.csv", 'rb').read)
    attachment.type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    attachment.filename = "#{@subject}.csv"
    attachment.disposition = 'attachment'
    attachment.content_id = 'Reports Sheet'
    mail.add_attachment(attachment)

    # also try: mail.add_attachment('/tmp/report.pdf', 'july_report.pdf')
    puts "Sending email 1"
    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)
    puts response.status_code

    puts ""
    puts "Sending email 2"
    mail = Mail.new(from, subject, from, content)
    mail.add_attachment(attachment)
    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)
    puts response.status_code


  end
end

name = ARGV[0]
email = ARGV[1]
Callrailreports.new(name, email).run
