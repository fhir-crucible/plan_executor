module Crucible
  module Tests
    class ArgonautResprint2Test < BaseSuite
      attr_accessor :rc
      attr_accessor :conformance
      attr_accessor :patient_id

      def id
        'ArgonautResprint2Test'
      end

      def description
        'In Re-Sprint 2, we\'ll get up to speed on Argonaut\'s updated implementation guidance for Vital Signs and Laboratory Results, while also introducing the Smoking Status Observation and CareTeam resources.'
      end

      def details
        {
          'Overview' => 'Since the Argonaut Implementation Program began in 2015, we\'ve come a long way. We\'ve gained early implementation experience working with FHIR DSTU2 and the Data Access Framework profiles — and we\'ve produced updated guidance based on this experience. We\'re running a series of "Re-Sprints" with three goals: ensure we have a chance to battle-test our latest "best practices" in time for MU3; help existing Argonaut implementers come up to speed; and provide an easy on-ramp for new Argonaut implementers.',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprints Spreadsheet. You\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly. If you\'re working on a client, please complete the "clients" tab of the Sprints Spreadsheet. You\'ll also need to update the status flag to indicate whether you\'ve begun work (or completed work).',
          'FHIR API Calls' => 'For this sprint, EHRs should focus on the following FHIR Resources: Observation, DiagnosticReport, and CareTeam.'
        }
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @rc = FHIR::Patient
        @tags.append('argonaut')
        @category = {id: 'argonaut', title: 'Argonaut'}
        @loinc_codes = ['8716-3', '9279-1', '8867-4', '59408-5', '8310-5', '8302-2', '8306-3', '8287-5', '29463-7', '39156-5', '55284-4', '8480-6', '8462-4']
        @loinc_code_units = {'8716-3' => nil, '9279-1' => '/min', '8867-4' => '/min', '59408-5' => '%', '8310-5' => 'Cel', '8302-2' => 'cm', '8306-3' => 'cm', '8287-5' => 'cm', '29463-7' => 'g, kg', '39156-5' => 'kg/m2', '55284-4' => nil, '8480-6' => 'mm[Hg]', '8462-4' => 'mm[Hg]'}
        @smoking_codes = ['449868002', '428041000124106', '8517006', '266919005', '77176002', '266927001', '428071000124103', '428061000124105']
      end

      def setup
        if !@client.client.try(:params).nil? && @client.client.params['patient']
          @patient_id = @client.client.params['patient']
        end
      end

      test 'ARS201', 'Get patient by ID' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["read", "search"]
          validates resource: "Patient", methods: ["read", "search"]
        }

        begin
          options = {
            :search => {
              :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 1
              }
            }
          }
          @patient_id ||= @client.search(@rc, options).resource.entry.first.resource.xmlId
        rescue NoMethodError
          @patient_id = nil
        end

        skip if !@patient_id

        reply = @client.read(FHIR::Patient, @patient_id)
        assert_response_ok(reply)
        assert_equal @patient_id, reply.id, 'Server returned wrong patient.'
        @patient = reply.resource
        assert @patient, "could not get patient by id: #{@patient_id}"
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'ARS202', 'GET vital-sign Observations with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Observation", methods: ["read", "search"]
          validates resource: "Observation", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id,
              category: 'vital-signs'
            }
          }
        }

        reply = @client.search(FHIR::Observation, options)

        validate_vitalsign_reply(reply)
      end

      test 'ARS203', 'GET coded Observation with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Observation", methods: ["read", "search"]
          validates resource: "Observation", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id,
              code: @loinc_codes.join(',')
            }
          }
        }

        reply = @client.search(FHIR::Observation, options)

        validate_vitalsign_reply(reply)
      end

      test 'ARS204', 'GET coded Observation with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Observation", methods: ["read", "search"]
          validates resource: "Observation", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id,
              category: 'laboratory'
            }
          }
        }

        reply = @client.search(FHIR::Observation, options)

        validate_lab_reply(reply)
      end

      test 'ARS205', 'GET DiagnosticReport with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "DiagnosticReport", methods: ["read", "search"]
          validates resource: "DiagnosticReport", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id,
              category: 'LAB'
            }
          }
        }

        reply = @client.search(FHIR::DiagnosticReport, options)

        validate_diagnostic_report_reply(reply)
      end

      test 'ARS206', 'GET Smoking Status Observation with patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'Observation', methods: ['read', 'search']
          validates resource: 'Observation', methods: ['read', 'search']
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id,
              code: '72166-2'
            }
          }
        }

        reply = @client.search(FHIR::Observation, options)

        validate_smoking_status_reply(reply)
      end

      test 'ARS207', 'GET CarePlan with patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'CarePlan', methods: ['read', 'search']
          validates resource: 'CarePlan', methods: ['read', 'search']
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id,
              category: 'careteam',
              status: 'active'
            }
          }
        }

        reply = @client.search(FHIR::CarePlan, options)

        validate_care_plan_reply(reply)
      end

      private

      def validate_care_plan_reply(reply)
        assert_response_ok(reply)

        valid_care_plans_count = 0

        reply.resource.entry.each do |entry|
          careplan = entry.resource
          if careplan.category.to_a.find { |cat| cat.coding.to_a.find { |c| c.system == "http://argonaut.hl7.org/ValueSet/extension-codes" && c.code == 'careteam' } }
            valid_care_plans_count += 1
            assert careplan.subject
            assert_equal careplan.subject.reference, "Patient/#{@patient_id}", "Expected patient #{@patient_id} did not match CarePlan Subject #{careplan.subject.reference}"
            careplan.participant.each do |participant|
              assert participant.role, "Participant '#{participant.id}' does not have a role"
              assert participant.member.display, "Participant '#{participant.id}' does not have a complete name in Participant.member.display"
            end
          end
        end

        warning { assert valid_care_plans_count > 0, "No care team CarePlans were found for this patient" }
        skip unless valid_care_plans_count > 0

      end

      def validate_smoking_status_reply(reply)
        assert_response_ok(reply)

        valid_smoking_status_count = 0

        reply.resource.entry.each do |entry|
          observation = entry.resource
          if observation.code.coding.to_a.find { |c| c.system == 'http://loinc.org' && c.code == '72166-2' }
            valid_smoking_status_count += 1
            assert !observation.status.empty?
            assert observation.subject
            assert_equal observation.subject.reference, "Patient/#{@patient_id}"
            assert observation.issued, "No instant available in observation '#{observation.xmlId}'s' 'issued' field"
            assert observation.valueCodeableConcept "No codeableConcept specified for Observation '#{observation.xmlId}''"
            assert observation.valueCodeableConcept.coding.to_a.find{|c|@smoking_codes.include?(c.code)}, "Observation valueCodeableConcept #{observation.valueCodeableConcept.to_fhir_json} isn't part of DAF Smoking Status Value Set"
          end
        end

        warning { assert valid_smoking_status_count > 0, "No smoking status Observations were found for this patient" }
        skip unless valid_smoking_status_count > 0
      end

      def validate_vitalsign_reply(reply)
        assert_response_ok(reply)

        valid_observation_count = 0

        reply.resource.entry.each do |entry|
          observation = entry.resource
          if observation.category.nil?
            warning { assert observation.category, "An observation did not have a category"}
            next
          end
          if observation.category.coding.to_a.find { |c| c.code == "vital-signs" }
            valid_observation_count += 1
            assert !observation.status.empty?
            assert observation.category
            assert observation.category.coding.to_a.find { |c| c.system == "http://hl7.org/fhir/observation-category" }, "Wrong category codeSystem used, expected FHIR ObservationCategory"
            assert observation.subject
            assert get_value(observation) || observation.dataAbsentReason || !observation.component.blank?
            coding = observation.code.coding.first
            assert coding.system == "http://loinc.org", "The observation is coded using the wrong code system, is #{coding.system}, should be LOINC"
            warning { assert @loinc_codes.index(coding.code), "The code included in an Observation doesn't match any in the code lists provided by the Argonaut project" }
            if @loinc_code_units[coding.code] && get_value(observation)
              value = get_value(observation)
              if value.respond_to? :unit
                assert_equal @loinc_code_units[coding.code], value.unit, "The unit of the observation is not correct."
              end
            end
            # systolic and diastolic in components
            if coding.code == '55284-4'
              assert observation.component.length >= 2, "expected at least 2 components for combined blood pressure grouping structure"
              systolic = observation.component.to_a.find {|component| component.code.coding.first.code == '8480-6'}
              diastolic = observation.component.to_a.find {|component| component.code.coding.first.code == '8462-4'}
              assert !systolic.blank?, "could not find a systolic blood pressure on a bp grouping vital sign observation"
              assert !diastolic.blank?, "could not find a diastolic blood pressure on a bp grouping vital sign observation"
              assert get_value(systolic), "systolic blood pressure did not have a value"
              assert_equal 'mmHg', get_value(systolic).unit, "The unit of the systolic blood pressure is not correct."
              assert get_value(diastolic), "systolic blood pressure did not have a value"
              assert_equal 'mmHg', get_value(diastolic).unit, "The unit of the systolic blood pressure is not correct."
            end

          end
        end
        warning { assert valid_observation_count > 0, "No vital signs Observations were found for this patient" }
        skip unless valid_observation_count > 0
      end

      def validate_diagnostic_report_reply(reply)
        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          report = entry.resource

          assert report.category, "DiagnosticReport has no category"
          assert report.category.coding.each do |c|
            assert c.code=='LAB',"Category code should be 'LAB'"
          end
          assert report.status, "No status for DiagnosticReport"
          assert report.code, "DiagnosticReport has no code"
          assert report.subject, "DiagnosticReport has no subject"
          assert report.effectivePeriod? || report.effectiveDateTime?, "DiagnosticReport has no effective date/time"
          assert report.issued, "DiagnosticReport has no issued"
          assert report.performer, "DiagnosticReport has no performer"
          assert report.result, "DiagnosticReport has no results"
        end
      end

      def validate_lab_reply(reply)
        assert_response_ok(reply)

        valid_observation_count = 0

        reply.resource.entry.each do |entry|
          observation = entry.resource
          if observation.category.nil?
            warning { assert observation.category, "An observation did not have a category"}
            next
          end
          if observation.category.coding.to_a.find { |c| c.code == "laboratory" }
            valid_observation_count += 1
            assert !observation.status.empty?
            assert observation.category
            assert observation.category.coding.to_a.find{ |c| c.system == "http://hl7.org/fhir/observation-category" }, "Wrong category codeSystem used, expected FHIR ObservationCategory"
            assert observation.subject
            assert get_value(observation) || observation.dataAbsentReason
            coding = observation.code.coding.first
            assert coding.system == "http://loinc.org", "The observation is coded using the wrong code system, is #{coding.system}, should be LOINC"
          end
        end
        warning { assert valid_observation_count > 0, "No laboratory Observations were found for this patient" }
        skip unless valid_observation_count > 0
      end

      def get_value(observation)
        observation.valueQuantity || observation.valueCodeableConcept || observation.valueString || observation.valueRange || observation.valueRatio || observation.valueSampledData || observation.valueAttachment || observation.valueTime || observation.valueDateTime || observation.valuePeriod
      end

    end
  end
end
