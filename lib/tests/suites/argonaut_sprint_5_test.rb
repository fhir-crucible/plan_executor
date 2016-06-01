module Crucible
  module Tests
    class ArgonautSprint5Test < BaseSuite
      def id
        'ArgonautSprint5Test'
      end

      def description
        'Argonaut Project Sprint 5 Test, to test success of servers at implementing goals of Argonaut Sprint 5'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 5 focuses on the scenario where a clinician launches a care management app from within the EHR. Building on Sprint 4\'s objectives, we add support for exposing a patient\'s problem list, and allergy list as well as more advanced app/EHR integration using additional parameters in SMART\'s "EHR Launch Flow".',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprint 5 Spreadsheet. This time around you\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly.',
          'FHIR API Calls' => 'For this sprint, EHRs should add support for: GET /Patient/{id}/Condition or GET /Condition?patient={id}: Retrieve any conditions (problems) on a patient\'s list, including current as well as resolved conditions, all coded in SNOMED CT per the DAF profile. GET /Patient/{id}/AllergyIntolerance or GET /AllergyIntolerance?patient={id}: Retrieve any allegies on a patient\'s list. Values are coded in NDF-RT (for drug class allergies), RxNorm (for drug ingredient allergies), UNII (for other substance allergies), or SNOMED CT (if all else fails).',
          'Authorization' => 'This sprint builds on Sprint 4\'s authorization scenario, adding two more context parameters to the launch response, both designed to improve the visual integration of third-party apps within a surrounding EHR system: need_patient_banner; indicates whether the app is responsible for displaying a demographic banner identifying the patient (should be set to true when an EHR does not already display such data in a frame around the app), and smart_style_url; indicates a set of style parameters (preferred colors, etc.) that the app may want to use.'
          }
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('argonautp1')
        @category = {id: 'argonautp1', title: 'Argonaut Phase 1'}
      end

      # [SprinklerTest("AS5001", "GET patient by ID")]
      test 'AS5001', 'GET patient by ID' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["read"]
          validates resource: "Patient", methods: ["read"]
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        reply = @client.read(FHIR::Patient, patient_id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)

        assert_response_ok(reply)
        assert_equal patient_id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'AS5002', 'GET Condition Patient Compartment for a specific patient' do
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
            :compartment => "Condition",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on condition does not match patient requested"
          entry.resource.code.coding.each do |coding|
            assert coding.system == "http://snomed.info/sct", "Code System is not SNOMEDCT"
            assert !coding.code.empty?, "No code defined for coding"
          end
        end
      end

      test 'AS5003', 'GET Condition with Patient IDs' do
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

        reply = @client.search(FHIR::Condition, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on condition does not match patient requested"
          entry.resource.code.coding.each do |coding|
            assert coding.system == "http://snomed.info/sct", "Code System is not SNOMEDCT"
            assert !coding.code.empty?, "No code defined for coding"
          end
        end
      end

      test 'AS5004', 'GET AllergyIntolerance Patient Compartment for a specific patient' do
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
            :compartment => "AllergyIntolerance",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on AllergyIntolerance does not match patient requested"
          assert entry.resource.substance, "No substance defined for AllergyIntolerance"
          entry.resource.substance.coding.each do |coding|
            assert ['http://fda.gov/UNII/', 'http://rxnav.nlm.nih.gov/REST/Ndfrt', 'http://snomed.info/sct', 'http://www.nlm.nih.gov/research/umls/rxnorm'].include?(coding.system), "Code system #{coding.system} does not match expected code systems."
          end
        end
      end

      test 'AS5005', 'GET AllergyIntolerance with Patient IDs' do
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

        reply = @client.search(FHIR::AllergyIntolerance, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on AllergyIntolerance does not match patient requested"
          assert entry.resource.substance, "No substance defined for AllergyIntolerance"
          entry.resource.substance.coding.each do |coding|
            assert ['http://fda.gov/UNII/', 'http://rxnav.nlm.nih.gov/REST/Ndfrt', 'http://snomed.info/sct', 'http://www.nlm.nih.gov/research/umls/rxnorm'].include?(coding.system), "Code system #{coding.system} does not match expected code systems."
          end
        end
      end
    end
  end
end
