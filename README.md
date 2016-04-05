# Department of Labor Case Lookup

Ruby script to track Department of Labor cases.

## Installation

[Download and install Ruby](https://www.ruby-lang.org/en/documentation/installation/ "Ruby install documentation").

## Usage

Update search parameters in the following section:

```ruby
=begin
=> Search parameters
=end

start_date = "10/1/2015"
end_date = "10/31/2015"
state_id = 'ALL'
case_id = "A-00000-00000"
employer_name = "Google"
visa_class_id = 6
h1b_data_series = 'ALL'
#...
```
Please, check lookup values below.

Execute the sctipt by the following command:
```
ruby icert_case_lookup.rb
```

## Response usage sample

```ruby
 json_hash["ROWS"].each { |array|
 	response_row_id = array[0]
 	response_case_id = array[1]
 	response_job_posting_date = array[2]
 	response_case_type = array[3]
 	response_case_status = array[4]
 	response_employer_name = array[5]
 	response_work_start_date = array[6]
 	response_work_end_date = array[7]
 	response_job_title = array[8]
 	response_state = array[9]
 	}
```

In the result of search you get the following columns:

| Columns          | Variables                 |
| ---------------- |:--------------------------|
| ID               | response_row_id           |
| ETA Case Number  | response_case_id          |
| Job Posting Date | response_job_posting_date |
| Case Type        | response_case_type        |
| Status           | response_case_status      |
| Employer Name    | response_employer_name    |
| Work Start Date  | response_work_start_date  |
| Work End Date    | response_work_end_date    |
| Job Title        | response_job_title        |
| State/Territory  | response_state            |
| Job Order        | ???                       |
| Cert             | ???                       |

`ID` gives you ability to get direct link to submitted certification document:
Here is the code sample:
```ruby
# Sample of the URL to get the document
icert_document_url = "https://icert.doleta.gov/index.cfm?event=ehLCJRExternal.dspCert&visa_class_id=#{visa_class_id}&id=#{response_row_id}"
```

### Lookups
#### Lookup `state_id`:
```
'ALL' - search all states
1 - alabama
2 - alaska
3 - arizona
4 - arkansas
5 - california
6 - colorado
7 - connecticut
8 - delaware
9 - district of columbia
10 - florida
11 - georgia
12 - guam
13 - hawaii
14 - idaho
15 - illinois
16 - indiana
17 - iowa
18 - kansas
19 - kentucky
20 - louisiana
21 - maine
22 - maryland
23 - massachusetts
24 - michigan
25 - minnesota
26 - mississippi
27 - missouri
28 - montana
29 - nebraska
30 - nevada
31 - new hampshire
32 - new jersey
33 - new mexico
34 - new york
35 - north carolina
36 - north dakota
58 - northern mariana islands
37 - ohio
38 - oklahoma
39 - oregon
40 - pennsylvania
41 - puerto rico
42 - rhode island
43 - south carolina
44 - south dakota
45 - tennessee
46 - texas
47 - utah
48 - vermont
49 - virgin islands
50 - virginia
51 - washington
52 - west virginia
53 - wisconsin
54 - wyoming
```

#### Lookup `visa_class_id`:
```
5 - All
6 - PERM
1 - H-1B
2 - H-1B1 Chile
3 - H-1B1 Singapore
4 - E-3 Australian
8 - H-2A
7 - H-2B
```

#### Lookup `h1b_data_series`:
Applicable **only if** `visa_class_id` is set to `1` (H-1B).
```
ALL - All
2016 - FY 2016
2015 - FY 2015
2014 - FY 2014
2013 - FY 2013
2012 - FY 2012
2011 - FY 2011
2010 - FY 2010
2009 - FY 2009
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## History

1.0.0.0 Initial implementation