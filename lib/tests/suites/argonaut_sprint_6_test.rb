module Crucible
  module Tests
    class ArgonautSprint6Test < BaseSuite
      def id
        'ArgonautSprint6Test'
      end

      def description
        'Argonaut Project Sprint 6 Test, to test success of servers at implementing goals of Argonaut Sprint 6'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 6 begins support for laboratory results. To provide very specific guidance in this first lab-related sprint, we address two common quantitative lab panels: the Comprehensive Metabolic Panel and the Complete Blood Count (without differential). On the security side, we add support for OAuth 2.0 refresh_tokens, which allow apps to receive long-lasting access.',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprint 5 Spreadsheet. This time around you\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly.',
          'FHIR API Calls' => 'For this sprint, EHRs should add support for: GET /Patient/{id}/DiagnosticReport or GET /DiagnosticReport?patient={id}--Retrieve any Laboratory Diagnostic Reports about a given patient. GET /Patient/{id}/Observation or GET /Observation?patient={id}--Retrieve any Observations about a given Patient. Our focus for Sprint 6 is on quantitative lab observations. Other kinds of Diagnostic Reports and Observations may be ignored. As an initial step, we will be focusing on final reports for Comprehensive metabolic panel and Complete Blood Count.',
          'Authorization' => 'This sprint builds out support for OAuth 2.0 refresh tokens. For full details, see SMART\'s table of scopes and the authorization guide, but briefly: At authorization time, an app asks for the offline_access. This scope indicates to the server that a long-lasting refresh token is desired. After launch, if the request has been approved, the app will receive a refresh_token as part of its access token response. Once the access_token expires, the app can ask for a new one by using its refresh_token.'
          }
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('argonautp1')
        @loinc_codes = ['2951-2', '2823-3', '2075-0', '2028-9', '3094-0', '2160-0', '2345-7', '17861-6', '2885-2', '1751-7', '1975-2', '6768-6', '1742-6', '1920-8', '6690-2', '  789-8', ' 718-7', ' 4544-3', '787-2', '785-6', '786-4', '21000-5', '788-0', '777-3', '32207-3', '32623-1']
        @category = {id: 'argonautp1', title: 'Argonaut Phase 1'}
      end

      # [SprinklerTest("AS6001", "GET patient by ID")]
      test 'AS6001', 'GET patient by ID' do
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
        assert_equal patient_id.to_s, reply.id.to_s, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'AS6002', 'GET Observation Patient Compartment for a specific patient' do
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

      test 'AS6003', 'GET Observation with Patient ID' do
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

      test 'AS6004', 'GET DiagnosticReport Patient Compartment for a specific patient' do
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
            :compartment => "DiagnosticReport",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        validate_diagnostic_report_reply(reply)
      end

      test 'AS6005', 'GET DiagnosticReport with Patient ID' do
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

        reply = @client.search(FHIR::DiagnosticReport, options)

        validate_diagnostic_report_reply(reply)
      end

      private

      def validate_diagnostic_report_reply(reply)
        assert_response_ok(reply)

        metabolic_index = -1
        reply.resource.entry.each_with_index do |e,i|
          r = e.resource
          categories = r.category.coding.map{|c|c.code.downcase}
          codes = r.code.coding.map{|c|c.code}
          metabolic_index = i if categories.include?('ch') && codes.include?('24323-8')
        end
        warning { assert (metabolic_index >= 0), "Metabolic panel with category 'CH' code '24323-8' not found." }
        metabolic_panel_entry = reply.resource.entry[metabolic_index] if metabolic_index >= 0
        
        blood_index = -1
        reply.resource.entry.each_with_index do |e,i|
          r = e.resource
          categories = r.category.coding.map{|c|c.code.downcase}
          codes = r.code.coding.map{|c|c.code}
          blood_index = i if categories.include?('hm') && codes.include?('58410-2')
        end
        warning { assert (metabolic_index >= 0), "Blood panel with category 'HM' code '58410-2' not found." }
        blood_count_panel_entry = reply.resource.entry[blood_index] if blood_index >= 0

        skip if metabolic_panel_entry.nil? && blood_count_panel_entry.nil?

        [ metabolic_panel_entry, blood_count_panel_entry ].keep_if{|x|!x.nil?}.each do |entry|
          report = entry.resource
          assert report.category, "DiagnosticReport has no category"
          if report.category.coding.to_a.find { |c| c.code.downcase == "ch" || c.code.downcase == "hm" }
            assert report.category.coding.to_a.find { |c| c.system == "http://hl7.org/fhir/v2/0074" }, "Wrong category codeSystem used; expected HL7v2"
            assert report.status, "No status for DiagnosticReport"
            assert report.code, "DiagnosticReport has no code"
            coding = report.code.coding.first
            assert coding.system == "http://loinc.org", "The DiagnosticReport is coded using the wrong code system, is #{coding}, should be LOINC"
            assert coding.code == "24323-8" || coding.code == "58410-2", "Wrong code used in DiagnosticReport"
            assert report.subject, "DiagnosticReport has no subject"
            assert report.effectivePeriod? || report.effectiveDateTime?, "DiagnosticReport has no effective date/time"
            assert report.issued, "DiagnosticReport has no issued"
            assert report.performer, "DiagnosticReport has no performer"
            assert report.result, "DiagnosticReport has no results"
          end
        end
      end

      def validate_observation_reply(reply)
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
            warning { assert @loinc_codes.index(coding.code), "The Observation code does not match any of the expected codes within Sprint 6." }
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
