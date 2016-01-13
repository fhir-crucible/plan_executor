module Crucible
  module Tests
    class ArgonautSprint3Test < BaseSuite
      def id
        'ArgonautSprint3Test'
      end

      def description
        'Argonaut Project Sprint 3 Test, to test success of servers at implementing goals of Argonaut Sprint 3'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 3 focuses on the scenario where a user approves an app with limited permissions, scoped down to a a single patient record. The app will have access to patient demographics and any "documents" available about that patient.',
          'Instructions' => 'Please sign up!  If you\'re working on a server, please complete the "servers" tab of the Sprint 3 Spreadsheet. This time around you\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly.  If you\'re working on a client, please complete the "clients" tab of the Sprint 3 Spreadsheet. You\'ll also need to update the status flag to indicate whether you\'ve begun work (or completed work).',
          'FHIR API Calls' => 'GET /Patient/{id} Retrieve a patient\'s basic demographics and identifiers, given a unique patient id.  GET /Patient/{id}/DocumentReference?type={}&created={} Search for available documents about a patient, given a unique patient id. Optional search parameters can filter results on:   - type a code describing this document (see below for details)   - created creation date   - Notes  Argonaut Document Access provides background on how the DocumentReference endpoint works — but note this guide is a work in progress, and our first sprint starts with just a subset of functionality.  The Argonaut Implementation Program now uses FHIR DSTU2.',
          'Authorization' => 'This sprint builds on our introduction to the SMART on FHIR OAuth 2.0 authorization process. Recall that in Sprint 2, we authorized access at a very coarse level, delegating all of a user\'s read privileges to an app. This time, we add support for apps that don\'t need access to an entire population of patient records, but instead require just one record. We accomplish this through a set of "launch scopes". In terms of SMART\'s authorization guide, we\'ll make the following assumptions:  Standalone launch sequence only Public clients and confidential clients are both supported Access scopes include: launch/patient (indicates to the EHR that a single patient must be selected to complete the launch process) patient/*.read (to ensure a patient-specific access token) Onecontext parameter is returned to the app upon successful authorization:   - patient (indicates the patient currently open in the EHR) - No single-sign-on (OpenID Connect) is required'
        }
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

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        reply = @client.read(FHIR::Patient, patient_id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)

        assert_response_ok(reply)
        assert_equal patient_id.to_s, reply.id.to_s, 'Server returned wrong patient.'
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

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
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
          assert !entry.resource.content.empty?, "DocumentReference must have at least one 'content' BackboneElement"
          entry.resource.content.each do |content|
            attachment = @client.get(URI::encode(@client.strip_base(content.attachment.url)), @client.fhir_headers())
            assert_response_ok(attachment)
          end
        end
      end

      test 'AS3003', 'GET DocumentReferences with Patient IDs' do
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

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert !entry.resource.content.empty?, "DocumentReference must have at least one 'content' BackboneElement"
          entry.resource.content.each do |content|
            attachment = @client.get(URI::encode(@client.strip_base(content.attachment.url)), @client.fhir_headers())
            assert_response_ok(attachment)
          end
        end
      end

      test 'AS3004', 'GET DocumentReference by Created Date' do
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
              patient: patient_id,
              created: '2015'
            }
          }
        }

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert !entry.resource.content.empty?, "DocumentReference must have at least one 'content' BackboneElement"
          entry.resource.content.each do |content|
            attachment = @client.get(URI::encode(@client.strip_base(content.attachment.url)), @client.fhir_headers())
            assert_response_ok(attachment)
          end
        end
      end

      test 'AS3005', 'GET DocumentReference by Type' do
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
              patient: patient_id,
              type: 'http://loinc.org|34133-9'
            }
          }
        }

        reply = @client.search(FHIR::DocumentReference, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert !entry.resource.content.empty?, "DocumentReference must have at least one 'content' BackboneElement"
          entry.resource.content.each do |content|
            attachment = @client.get(URI::encode(@client.strip_base(content.attachment.url)), @client.fhir_headers())
            assert_response_ok(attachment)
          end
        end
      end

    end
  end
end
