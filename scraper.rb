require 'scraperwiki'
require 'mechanize'

case ENV['MORPH_PERIOD']
when 'thismonth'
  period = 'thismonth'
when 'lastmonth'
  period = 'lastmonth'
else
  period = 'thisweek'
end
puts "Getting '" + period + "' data, changable via MORPH_PERIOD environment";

url_base    = 'http://pdonline.redland.qld.gov.au'
da_url      = url_base + '/Pages/XC.Track/SearchApplication.aspx?d=' + period + '&k=LodgementDate&t=BD,BW,BA,MC,MCU,OPW,BWP,APS,MCSS,OP,EC,SB,SBSS,PD,BX,ROL,QRAL'

# setup agent and turn off gzip as council web site returning 'encoded-content: gzip,gzip'
agent = Mechanize.new
agent.request_headers = { "Accept-Encoding" => "" }

# Accept terms
page = agent.get(url_base + '/Common/Common/terms.aspx')
form = page.forms.first
form["ctl00$ctMain$BtnAgree"] = "I Agree"
page = form.submit

# Scrape DA page
page = agent.get(da_url)
results = page.search('div.result')

results.each do |result|
  council_reference = result.search('a.search')[0].inner_text.strip.split.join(" ")

  description = result.inner_text
  description = description.split( /\r?\n/ )
  description = description[4].strip.split.join(" ")

  info_url    = result.search('a.search')[0]['href']
  info_url    = info_url.sub!('../..', '')
  info_url    = url_base + info_url

  date_received = result.inner_text
  date_received = date_received.split( /\r?\n/ )
  begin
    date_received = Date.parse(date_received[6].strip.to_s)
  rescue ArgumentError
    date_received = nil
  end

  record = {
    'council_reference' => council_reference,
    'address'           => result.search('strong')[0].inner_text.strip.split.join(" "),
    'description'       => description,
    'info_url'          => info_url,
    'date_scraped'      => Date.today.to_s,
    'date_received'     => date_received
  }

  if date_received.nil?
    puts "Date received wasn't valid for this record so skipping: #{record.inspect}"
    next
  end

  # Saving data
  puts "Saving record " + record['council_reference'] + ", " + record['address']
#    puts record
  ScraperWiki.save_sqlite(['council_reference'], record)
end
