#!/usr/bin/env ruby
# Generates small XLSX fixture files for tests using caxlsx

require "caxlsx"

FIXTURE_DIR = File.join(__dir__, "fixtures")

def generate_lca_fixture
  package = Axlsx::Package.new
  package.workbook.add_worksheet(name: "LCA") do |sheet|
    headers = %w[
      CASE_NUMBER CASE_STATUS RECEIVED_DATE DECISION_DATE VISA_CLASS
      EMPLOYER_NAME TRADE_NAME_DBA EMPLOYER_CITY EMPLOYER_STATE
      JOB_TITLE SOC_TITLE WAGE_RATE_OF_PAY_FROM WAGE_RATE_OF_PAY_TO
      WAGE_UNIT_OF_PAY WORKSITE_CITY WORKSITE_STATE PREVAILING_WAGE
    ]
    sheet.add_row(headers)

    data = [
      ["I-200-12345-678901", "Certified", "01/15/2024", "02/01/2024", "H-1B",
       "GOOGLE LLC", "GOOGLE", "MOUNTAIN VIEW", "CA",
       "SOFTWARE ENGINEER", "Software Developers", "180000", "210000",
       "Year", "MOUNTAIN VIEW", "CA", "165000"],
      ["I-200-12345-678902", "Certified", "01/20/2024", "02/05/2024", "H-1B",
       "APPLE INC", "", "CUPERTINO", "CA",
       "SENIOR SOFTWARE ENGINEER", "Software Developers", "200000", "250000",
       "Year", "CUPERTINO", "CA", "175000"],
      ["I-200-12345-678903", "Denied", "02/01/2024", "02/15/2024", "H-1B",
       "META PLATFORMS INC", "FACEBOOK", "MENLO PARK", "CA",
       "DATA SCIENTIST", "Data Scientists", "190000", "220000",
       "Year", "MENLO PARK", "CA", "170000"],
      ["I-200-12345-678904", "Certified", "02/10/2024", "02/25/2024", "H-1B",
       "MICROSOFT CORPORATION", "", "REDMOND", "WA",
       "PRINCIPAL ENGINEER", "Software Developers", "220000", "280000",
       "Year", "REDMOND", "WA", "185000"],
      ["I-200-12345-678905", "Certified", "03/01/2024", "03/15/2024", "H-1B1 Chile",
       "AMAZON.COM SERVICES LLC", "AMAZON", "SEATTLE", "WA",
       "SOFTWARE DEVELOPMENT ENGINEER", "Software Developers", "175000", "200000",
       "Year", "SEATTLE", "WA", "160000"],
      ["I-200-12345-678906", "Withdrawn", "03/05/2024", "03/20/2024", "E-3",
       "NETFLIX INC", "", "LOS GATOS", "CA",
       "SENIOR DATA ENGINEER", "Database Administrators", "195000", "230000",
       "Year", "LOS GATOS", "CA", "172000"],
      ["I-200-12345-678907", "Certified", "03/10/2024", "03/25/2024", "H-1B",
       "GOOGLE LLC", "GOOGLE", "NEW YORK", "NY",
       "PRODUCT MANAGER", "Computer and Info Systems Mgrs", "210000", "260000",
       "Year", "NEW YORK", "NY", "195000"],
      ["I-200-12345-678908", "Certified", "03/15/2024", "04/01/2024", "H-1B",
       "TESLA INC", "", "AUSTIN", "TX",
       "MACHINE LEARNING ENGINEER", "Software Developers", "185000", "225000",
       "Year", "AUSTIN", "TX", "168000"],
      ["I-200-12345-678909", "Certified - Withdrawn", "04/01/2024", "04/15/2024", "H-1B",
       "STRIPE INC", "", "SAN FRANCISCO", "CA",
       "BACKEND ENGINEER", "Software Developers", "190000", "230000",
       "Year", "SAN FRANCISCO", "CA", "175000"],
      ["I-200-12345-678910", "Certified", "04/10/2024", "04/25/2024", "H-1B",
       "UBER TECHNOLOGIES INC", "", "SAN FRANCISCO", "CA",
       "STAFF SOFTWARE ENGINEER", "Software Developers", "225000", "275000",
       "Year", "SAN FRANCISCO", "CA", "185000"],
    ]

    data.each { |row| sheet.add_row(row) }
  end

  path = File.join(FIXTURE_DIR, "lca_sample.xlsx")
  package.serialize(path)
  puts "Generated #{path}"
end

def generate_perm_fixture
  package = Axlsx::Package.new
  package.workbook.add_worksheet(name: "PERM") do |sheet|
    headers = %w[
      CASE_NUMBER CASE_STATUS RECEIVED_DATE DECISION_DATE VISA_CLASS
      EMPLOYER_NAME EMPLOYER_CITY EMPLOYER_STATE
      JOB_TITLE PW_SOC_TITLE WAGE_OFFER_FROM WAGE_OFFER_TO
      WAGE_OFFER_UNIT_OF_PAY WORKSITE_CITY WORKSITE_STATE PW_WAGE
    ]
    sheet.add_row(headers)

    data = [
      ["A-12345-67890", "Certified", "01/10/2024", "06/15/2024", "Immigrant",
       "GOOGLE LLC", "MOUNTAIN VIEW", "CA",
       "SOFTWARE ENGINEER III", "Software Developers", "185000", "220000",
       "Year", "MOUNTAIN VIEW", "CA", "165000"],
      ["A-12345-67891", "Denied", "02/01/2024", "07/01/2024", "Immigrant",
       "META PLATFORMS INC", "MENLO PARK", "CA",
       "RESEARCH SCIENTIST", "Computer and Info Research Scientists", "200000", "250000",
       "Year", "MENLO PARK", "CA", "180000"],
      ["A-12345-67892", "Certified", "03/15/2024", "08/20/2024", "Immigrant",
       "MICROSOFT CORPORATION", "REDMOND", "WA",
       "PRINCIPAL SOFTWARE ENGINEER", "Software Developers", "240000", "300000",
       "Year", "REDMOND", "WA", "190000"],
      ["A-12345-67893", "Certified", "04/01/2024", "09/10/2024", "Immigrant",
       "APPLE INC", "CUPERTINO", "CA",
       "HARDWARE ENGINEER", "Electrical Engineers", "195000", "240000",
       "Year", "CUPERTINO", "CA", "175000"],
      ["A-12345-67894", "Certified", "05/10/2024", "10/15/2024", "Immigrant",
       "AMAZON.COM SERVICES LLC", "SEATTLE", "WA",
       "SENIOR SDE", "Software Developers", "200000", "260000",
       "Year", "SEATTLE", "WA", "180000"],
    ]

    data.each { |row| sheet.add_row(row) }
  end

  path = File.join(FIXTURE_DIR, "perm_sample.xlsx")
  package.serialize(path)
  puts "Generated #{path}"
end

if __FILE__ == $0
  FileUtils.mkdir_p(FIXTURE_DIR)
  generate_lca_fixture
  generate_perm_fixture
end
