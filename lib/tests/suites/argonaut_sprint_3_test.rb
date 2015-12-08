module Crucible
  module Tests
    class ArgonautSprint3Test < BaseSuite
      def id
        'ArgonautSprint3Test'
      end

      def description
        'Argonaut Project Sprint 3 Test, to test success of servers at implementing goals of Argonaut Sprint 3'
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('argonaut')
      end

      # [SprinklerTest("AS3001", "GET patient by ID")]
      test 'AS3001', 'GET patient by ID' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["read"]
          validates resource: "Patient", methods: ["read"]
        }

        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        reply = @client.read(FHIR::Patient, patient_id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)

        assert_response_ok(reply)
        assert_equal patient_id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'AS3002', 'GET DocumentReference Patient Compartment for a specific patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Patient", methods: ["search"]
          validates resource: "Patient", methods: ["search"]
        }

        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        options = {
          :id => patient_id,
          :search => {
            :flag => false,
            :compartment => "DocumentReference",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert_equal entry.resource.subject.reference, "Patient/#{patient_id}", "DocumentReference ID does not match patient searched for"
        end
      end

      test 'AS3003', 'GET DocumentReferences with Patient IDs' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "DocumentReference", methods: ["read", "search"]
          validates resource: "DocumentReference", methods: ["read", "search"]
        }

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

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert_equal entry.resource.subject.reference, "Patient/#{patient_id}", "DocumentReference ID ()#{entry.resource.subject.reference}) does not match patient ID (patient_id)"
        end
      end

      test 'AS3004', 'GET DocumentReference by Created Date' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'DocumentReference', methods: ['read', 'search']
          validates resource: 'DocumentReference', methods: ['read', 'search']
        }

        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id,
              created: '2015'
            }
          }
        }

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert_equal entry.resource.subject.reference, "Patient/#{patient_id}", "DocumentReference ID ()#{entry.resource.subject.reference}) does not match patient ID (patient_id)"
        end
      end

      test 'AS3005', 'GET DocumentReference by Type' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'DocumentReference', methods: ['read', 'search']
          validates resource: 'DocumentReference', methods: ['read', 'search']
        }

        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id,
              type: 'http://loinc.org|34133-9'
            }
          }
        }

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert_equal entry.resource.subject.reference, "Patient/#{patient_id}", "DocumentReference ID ()#{entry.resource.subject.reference}) does not match patient ID (patient_id)"
        end
      end

    end
  end
end
