require 'net/http'
require 'openssl'
require 'date'
require 'json'
require 'pp'

=begin
=> Methods definition
=end

def get_response_by_specified_parameters(start_date, end_date, state_id, case_id, employer_name, visa_class_id, h1b_data_series)
  icert_request_url = "https://icert.doleta.gov/index.cfm?event=ehLCJRExternal.dspQuickCertSearchGridData" \
    "&&startSearch=1" \
    "&case_number=#{case_id}" \
    "&employer_business_name=#{employer_name}" \
    "&visa_class_id=#{visa_class_id}" \
    "&state_id=#{state_id}" \
    "&location_range=10" \
    "&location_zipcode=" \
    "&job_title=" \
    "&naic_code=" \
    "&create_date=undefined" \
    "&post_end_date=undefined" \
    "&h1b_data_series=#{h1b_data_series}" \
    "&start_date_from=#{start_date}" \
    "&start_date_to=#{end_date}" \
    "&end_date_from=mm/dd/yyyy" \
    "&end_date_to=mm/dd/yyyy" \
    "&page=1" \
    "&rows=60" \
    "&sidx=create_date" \
    "&sord=desc" \
    "&nd=1445285016948" \
    "&_search=false"

  uri = URI.parse(icert_request_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  response = http.get(uri.request_uri)

  return response
end

def parse_and_print_response(response)
  json_hash = JSON.parse(response.body)

  json_hash["ROWS"].each { |array|
    pp array
  }
end

def case_lookup(start_date, end_date, state_id, case_id, employer_name, visa_class_id, h1b_data_series)
  response = get_response_by_specified_parameters(start_date, end_date, state_id, case_id, employer_name, visa_class_id, h1b_data_series)

  parse_and_print_response(response)
end

=begin
<= Methods definition
=end

=begin
=> Search parameters
=end

start_date = "10/1/2015"
end_date = "10/31/2015" #Date.today.strftime("%m/%d/%Y").to_s
state_id = 'ALL' # Check lookup values in README
case_id = "A-00000-00000"
employer_name = "Google"
visa_class_id = 6 # Check lookup values in README
h1b_data_series = 'ALL' # Check lookup values in README

=begin
<= Search parameters
=end

# Method call
case_lookup(start_date, end_date, state_id, case_id, employer_name, visa_class_id, h1b_data_series)

# Sample of the URL to get the document
#icert_document_url = "https://icert.doleta.gov/index.cfm?event=ehLCJRExternal.dspCert&visa_class_id=#{visa_class_id}&id=#{response_rows_array[0]}"
