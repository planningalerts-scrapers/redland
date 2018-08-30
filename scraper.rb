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
comment_url = 'mailto:rcc@redland.qld.gov.au?subject=Development Application Enquiry: '

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
  date_received = Date.parse(date_received[6].strip.to_s)

  record = {
    'council_reference' => council_reference,
    'address'           => result.search('strong')[0].inner_text.strip.split.join(" "),
    'description'       => description,
    'info_url'          => info_url,
    'comment_url'       => comment_url + council_reference,
    'date_scraped'      => Date.today.to_s,
    'date_received'     => date_received
  }

  # Saving data
  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    puts "Saving record " + record['council_reference'] + ", " + record['address']
#    puts record
     ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Skipping already saved record " + record['council_reference']
  end
end

