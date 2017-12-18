require 'rest_client'
require 'json'
require 'sendgrid-ruby'
include SendGrid
require 'date'

class Callrailreports
  API_KEY = ENV['CALLRAIL_API']
  COMPANIES = {'adil' => '394784495', 'david' => '260767844'}
  PAYPERLEAD = {'adil' => 9, 'david' => 8}
  FROM_EMAIL = ENV['LEADSVET_EMAIL']

  def initialize(name, email)
    @name = name
    @email = email
    @company_id = COMPANIES[@name]
    @pay_per_lead = PAYPERLEAD[@name]
  end

  def run
    get_calls
    calculate_total
    send_report
    create_csv
  end

  def get_calls # connect to api and get json
    response = RestClient.get 'https://api.callrail.com/v2/a/831937628/calls.json', :authorization => "Token token=\"#{API_KEY}\"", :params => {company_id: @company_id, date_range: 'last_7_days', answer_status: 'answered'}
    # Parse the json response
    data = JSON.parse(response.body)

    # Access the array of companies
    calls = data['calls']

    # Array of hashes. Only calls over 90 seconds
    over_90_calls = calls.select do |call|
      call['recording_duration'] > 90
    end

    @calls_array = over_90_calls.uniq {|e| e[:customer_phone_number]}

  end

  def calculate_total
    @total_pay = @calls_array.size * @pay_per_lead
  end

  def create_csv

  end

  def send_report # parse the json, send the report as email
    from = Email.new(email: FROM_EMAIL)
    to = Email.new(email: @email)
    subject = "PLUMBING REPORT DATES: #{Date.today - 1} to #{Date.today - 7}"
    content = Content.new(type: 'text/plain', value: 'and easy to do anywhere, even with Ruby')
    mail = Mail.new(from, subject, to, content)

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)
    puts response.status_code
    puts response.body
    puts response.headers
  end
end

# ruby elocal_report.rb adil, info@craigslistadpostingservice.net
name = ARGV[0]
email = ARGV[1]
Callrailreports.new(name, email).run
