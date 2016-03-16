module Crucible
  module Tests
    class ArgonautSprint7Test < BaseSuite
      def id
        'ArgonautSprint7Test'
      end

      def description
        'Argonaut Project Sprint 7 Test, to test success of servers at implementing goals of Argonaut Sprint 7'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 7 adds support for vital signs. We want to ensure that vital signs are represented as individual resources, but also grouped explicitly into sets (e.g. heart rate, blood pressure, respiratory rate should be associated so they can be interpreted as a set).',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprints Spreadsheet. You\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly. If you\'re working on a client, please complete the "clients" tab of the Sprints Spreadsheet. You\'ll also need to update the status flag to indicate whether you\'ve begun work (or completed work).',
          'FHIR API Calls' => 'For this sprint, EHRs should build on Sprint 6\'s support for: GET /Patient/{id}/Observation or GET /Observation?patient={id} Retrieve any Observations about a given Patient. Our focus for Sprint 7 is on vital signs, which can be identified with codes in the table below. Note that it\'s possible to search for vital signs at the grouping level (that is, search for "all sets of vital signs" via ?code=http://loinc.org|8716-3) or at the individual level (for example, search for "all heart rates" via ?code=http://loinc.org|8867-4). It\'s also possible to find vital signs at all levels via ?category=http://hl7.org/fhir/observation-category|vital-signs',
          'Authorization' => 'This sprint does not have any additional authorization requirements.'
          }
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('argonaut')
        @loinc_codes = ['8716-3', '9279-1', '8867-4', '59408-5', '8310-5', '8302-2', '8306-3', '8287-5', '3141-9', '39156-5', '3140-1', '55284-4', '8480-6', '8462-4', '8478-0']
        @loinc_code_units = {'8716-3' => nil, '9279-1' => '/min', '8867-4' => '/min', '59408-5' => '%', '8310-5' => 'Cel', '8302-2' => 'cm', '8306-3' => 'cm', '8287-5' => 'cm', '3141-9' => 'g, kg', '39156-5' => 'kg/m2', '3140-1' => 'm2', '8478-0' => 'mm[Hg]'}
        @category = 'Argonaut'
      end


# Systolic blood pressure 8480-6  mm[Hg]  This lives in component on a "systolic and diastolic" Observation
# Diastolic blood pressure  8462-4  mm[Hg]  This lives in component on a "systolic and diastolic" Observation

      test 'AS7001', 'GET patient by ID' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["read"]
          validates resource: "Patient", methods: ["read"]
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        reply = @client.read(FHIR::Patient, patient_id)

        assert_response_ok(reply)
        assert_equal patient_id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'AS7002', 'GET Observation Patient Compartment for a specific patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Patient", methods: ["search"]
          validates resource: "Patient", methods: ["search"]
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        options = {
          :id => patient_id,
          :search => {
            :flag => false,
            :compartment => "Observation",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        validate_observation_reply(reply)
      end

      test 'AS7003', 'GET Observation with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Patient", methods: ["read", "search"]
          validates resource: "Patient", methods: ["read", "search"]
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id
            }
          }
        }

        reply = @client.search(FHIR::Observation, options)
        
        validate_observation_reply(reply)
      end


      private

      def validate_observation_reply(reply)
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
                assert_equal @loinc_code_units[coding.code], value.unit, "The unit of the observation is not correct"
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
              assert_equal 'mmHg', get_value(systolic).unit, "The unit of the systolic blood pressure is not correct"
              assert get_value(diastolic), "systolic blood pressure did not have a value"
              assert_equal 'mmHg', get_value(diastolic).unit, "The unit of the systolic blood pressure is not correct"
            end

          end
        end
        warning { assert valid_observation_count > 0, "No vital signs Observations were found for this patient" }
        skip unless valid_observation_count > 0
      end

      def get_value(observation)
        observation.valueQuantity || observation.valueCodeableConcept || observation.valueString || observation.valueRange || observation.valueRatio || observation.valueSampledData || observation.valueAttachment || observation.valueTime || observation.valueDateTime || observation.valuePeriod
      end
    end
  end
end
