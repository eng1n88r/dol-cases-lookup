module DolLookup
  module ColumnMap
    # Maps semantic field names to actual XLSX column headers per program.
    # DOL changes column names between programs and sometimes between quarters.
    MAPPINGS = {
      "lca" => {
        case_number:    "CASE_NUMBER",
        case_status:    "CASE_STATUS",
        employer_name:  "EMPLOYER_NAME",
        trade_name:     "TRADE_NAME_DBA",
        employer_city:  "EMPLOYER_CITY",
        employer_state: "EMPLOYER_STATE",
        job_title:      "JOB_TITLE",
        soc_title:      "SOC_TITLE",
        wage_from:      "WAGE_RATE_OF_PAY_FROM",
        wage_to:        "WAGE_RATE_OF_PAY_TO",
        wage_unit:      "WAGE_UNIT_OF_PAY",
        worksite_city:  "WORKSITE_CITY",
        worksite_state: "WORKSITE_STATE",
        received_date:  "RECEIVED_DATE",
        decision_date:  "DECISION_DATE",
        visa_class:     "VISA_CLASS",
        prevailing_wage: "PREVAILING_WAGE"
      },
      "perm" => {
        case_number:    "CASE_NUMBER",
        case_status:    "CASE_STATUS",
        employer_name:  "EMPLOYER_NAME",
        employer_city:  "EMPLOYER_CITY",
        employer_state: "EMPLOYER_STATE",
        job_title:      "JOB_TITLE",
        soc_title:      "PW_SOC_TITLE",
        wage_from:      "WAGE_OFFER_FROM",
        wage_to:        "WAGE_OFFER_TO",
        wage_unit:      "WAGE_OFFER_UNIT_OF_PAY",
        worksite_city:  "WORKSITE_CITY",
        worksite_state: "WORKSITE_STATE",
        received_date:  "RECEIVED_DATE",
        decision_date:  "DECISION_DATE",
        visa_class:     "VISA_CLASS",
        prevailing_wage: "PW_WAGE"
      },
      "h2a" => {
        case_number:    "CASE_NUMBER",
        case_status:    "CASE_STATUS",
        employer_name:  "EMPLOYER_NAME",
        trade_name:     "TRADE_NAME_DBA",
        employer_city:  "EMPLOYER_CITY",
        employer_state: "EMPLOYER_STATE",
        job_title:      "JOB_TITLE",
        wage_from:      "BASIC_RATE_OF_PAY",
        worksite_city:  "WORKSITE_CITY",
        worksite_state: "WORKSITE_STATE",
        received_date:  "RECEIVED_DATE",
        decision_date:  "DECISION_DATE",
        visa_class:     "VISA_CLASS"
      },
      "h2b" => {
        case_number:    "CASE_NUMBER",
        case_status:    "CASE_STATUS",
        employer_name:  "EMPLOYER_NAME",
        trade_name:     "TRADE_NAME_DBA",
        employer_city:  "EMPLOYER_CITY",
        employer_state: "EMPLOYER_STATE",
        job_title:      "JOB_TITLE",
        wage_from:      "BASIC_RATE_OF_PAY",
        worksite_city:  "WORKSITE_CITY",
        worksite_state: "WORKSITE_STATE",
        received_date:  "RECEIVED_DATE",
        decision_date:  "DECISION_DATE",
        visa_class:     "VISA_CLASS"
      }
    }.freeze

    # Display columns and their display labels (order matters for table output)
    DISPLAY_COLUMNS = {
      case_number:    "Case Number",
      case_status:    "Status",
      employer_name:  "Employer",
      job_title:      "Job Title",
      worksite_city:  "City",
      worksite_state: "State",
      wage_from:      "Wage",
      decision_date:  "Decision Date",
      visa_class:     "Visa Class"
    }.freeze

    def self.columns_for(program)
      MAPPINGS.fetch(program) { raise ArgumentError, "Unknown program: #{program}" }
    end

    def self.xlsx_column(program, field)
      columns_for(program).fetch(field) { raise ArgumentError, "Unknown field: #{field} for program: #{program}" }
    end
  end
end
