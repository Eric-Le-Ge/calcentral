module HubEdos
  class UserAttributes < Proxy

    def initialize(options = {})
      super(Settings.hub_edos_proxy, options)
      initialize_mocks if @fake
    end

    def self.test_data?
      @fake
    end

    def url
      ''
    end

    def json_filename
      'user_attributes.json'
    end

    def get_internal
      edo_feed = Student.new(user_id: @uid).get
      result = ActiveSupport::HashWithIndifferentAccess.new
      if (feed = edo_feed[:feed])
        edo = HashConverter.symbolize feed['student'] # TODO will have to dynamically switch student/person EDO somehow
        extract_passthrough_elements(edo, result)
        extract_ids(edo, result)
        extract_names(edo, result)
        extract_affiliations(edo, result)
        extract_emails(edo, result)
        extract_education_level(edo, result)
        extract_total_units(edo, result)
        extract_special_program_code(edo, result)
        extract_reg_status(edo, result)
        extract_residency(edo, result)
        result[:statusCode] = 200
      else
        logger.error "Could not get Student EDO data for uid #{@uid}"
      end
      result
    end

    def extract_passthrough_elements(edo, result)
      [:names, :addresses, :phones, :emails, :ethnicities, :languages, :emergencyContacts].each do |field|
        result[field] = edo[field]
      end
    end

    def extract_ids(edo, result)
      edo[:identifiers].each do |id|
        if id[:type] == 'CalNet UID'
          result[:ldap_uid] = id[:id]
        elsif id[:type] == 'Student ID'
          result[:student_id] = id[:id]
        end
      end
    end

    def extract_names(edo, result)
      edo[:names].each do |name|
        # use preferred name
        if name[:type][:code] == 'PRF'
          result[:first_name] = name[:givenName]
          result[:last_name] = name[:familyName]
          result[:person_name] = name[:formattedName]
          break
        end
      end
    end

    def extract_affiliations(edo, result)
      # TODO affiliations needs more business analysis and transformation.
      result[:affiliations] = edo[:affiliations]
      # TODO fill in roles with UserRoles#roles_from_affiliations logic
      result[:roles] = {
        student: true,
        registered: true,
        exStudent: false,
        faculty: false,
        staff: false,
        guest: false,
        concurrentEnrollmentStudent: false
      }
      result[:affiliations].each do |affiliation|
        if affiliation[:type][:code] == 'UNDERGRAD' && affiliation[:statusCode] == 'ACT'
          result[:ug_grad_flag] = 'U'
        elsif affiliation[:type][:code] == 'GRAD' && affiliation[:statusCode] == 'ACT'
          result[:ug_grad_flag] = 'G'
        end
      end
    end

    def extract_emails(edo, result)
      edo[:emails].each do |email|
        if email[:primary] == true
          result[:email_address] = email[:emailAddress]
        end
        if email[:type][:code] == 'CAMP'
          result[:official_bmail_address] = email[:emailAddress]
        end
      end
    end

    def extract_education_level(edo, result)
      # TODO this data only supported in GoLive5
      result[:education_level] = edo[:currentRegistration][:academicLevel][:level][:description]
    end

    def extract_total_units(edo, result)
      # TODO this data only supported in GoLive5
      edo[:currentRegistration][:termUnits].each do |term_unit|
        if term_unit[:type][:description] == 'Total'
          result[:tot_enroll_unit] = term_unit[:unitsEnrolled]
          break
        end
      end
    end

    def extract_special_program_code(edo, result)
      # TODO this data only supported in GoLive5
      result[:education_abroad] = false
      # TODO verify business correctness of this conversion based on more examples of study-abroad students
      edo[:currentRegistration][:specialStudyPrograms].each do |pgm|
        if pgm[:type][:code] == 'EAP'
          result[:education_abroad] = true
          break
        end
      end
    end

    def extract_reg_status(edo, result)
      # TODO populate based on SISRP-7581 explanation. Incorporate full structure from RegStatusTranslator.
      # TODO this data only supported in GoLive5
      result[:reg_status] = {}
    end

    def extract_residency(edo, result)
      # TODO this data only supported in GoLive5
      if edo[:residency][:official][:code] == 'RES'
        result[:cal_residency_flag] = 'Y'
      else
        result[:cal_residency_flag] = 'N'
      end
      if term_transition?
        result[:california_residency] = nil
        result[:reg_status][:transitionTerm] = true
      else
        # TODO get full status from CalResidencyTranslator
        #result[:california_residency] = cal_residency_translator.translate result[:cal_residency_flag]
      end
    end

    def term_transition?
      Berkeley::Terms.fetch.current.sis_term_status != 'CT'
    end

  end
end

