module Crucible
  module Tests
    class ArgonautSprint4Test < BaseSuite
      def id
        'ArgonautSprint4Test'
      end

      def description
        'Argonaut Project Sprint 4 Test, to test success of servers at implementing goals of Argonaut Sprint 4'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 4 focuses on the scenario where a clinician launches a medication list app from within the EHR. The app is given EHR context using SMART\'s "EHR Launch Flow", meaning that it knows the currently-open patient record (as well as the current user -- but we\'ll tackle that in Sprint 5). On successful launch, the app is authorized to view a set of patient-specific medication-related data.',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprint 4 Spreadsheet. This time around you\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly.',
          'FHIR API Calls' => 'FHIR provides a rich set of resource definitions for medication data. These include MedicationStatement, which expresses a high-level claim that a patient is (or is not) taking a specific drug, without further details about who prescribed it or how it was dispensed. MedicationOrder, MedicationDispense, MedicationAdministration, which are more detailed, workflow-oriented resources describing exactly what was prescribed, how it was dispensed, and how it was administered to the patient. The following search parameters must be supported at a minimum (code, identifier, medication, patient, status, effectivedate (for for MedicationStatement), datewritten (for MedicationOrder), prescriber (for MedicationOrder)). For this sprint, we ask EHRs to focus on two resources: GET /Patient/{id}/MedicationOrder or GET /MedicationOrder?patient={id} Retrieve any medications where the EHR directly manages a prescription. GET /Patient/{id}/MedicationStatement or GET /MedicationStatement?patient={id} Retrieve any other medications, including patient-reported over-the-counter drugs, or drugs manage by an outside provider or system.',
          'Authorization' => 'This sprint builds on our introduction to the SMART on FHIR OAuth 2.0 authorization process. Recall that in Sprint 2, we authorized access at a very coarse level, delegating all of a user\'s read privileges to an app. This time, we add support for apps that don\'t need access to an entire population of patient records, but instead require just one record. We accomplish this through a set of "launch scopes". In terms of SMART\'s authorization guide, we\'ll make the following assumptions:  Standalone launch sequence only Public clients and confidential clients are both supported Access scopes include: launch/patient (indicates to the EHR that a single patient must be selected to complete the launch process) patient/*.read (to ensure a patient-specific access token) Onecontext parameter is returned to the app upon successful authorization:   - patient (indicates the patient currently open in the EHR) - No single-sign-on (OpenID Connect) is required'
        }
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('argonaut')
        @category = {id: 'argonaut', title: 'Argonaut'}
      end

      # [SprinklerTest("AS3001", "GET patient by ID")]
      test 'AS4001', 'GET patient by ID' do
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

      test 'AS4002', 'GET MedicationOrder Patient Compartment for a specific patient' do
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
            :compartment => "MedicationOrder",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (!entry.resource.medicationReference.nil? || !entry.resource.medicationCodeableConcept.nil?), "MedicationOrder was missing a medication reference or codeable concept"
        end
      end

      test 'AS4003', 'GET MedicationOrder with Patient IDs' do
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

        reply = @client.search(FHIR::MedicationOrder, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (!entry.resource.medicationReference.nil? || !entry.resource.medicationCodeableConcept.nil?), "MedicationOrder was missing a medication reference or codeable concept"
        end
      end

      test 'AS4004', 'GET MedicationStatement Patient Compartment for a specific patient' do
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
            :compartment => "MedicationStatement",
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (!entry.resource.medicationReference.nil? || !entry.resource.medicationCodeableConcept.nil?), "MedicationStatement was missing a medication reference or codeable concept"
        end
      end

      test 'AS4005', 'GET MedicationStatement with Patient IDs' do
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

        reply = @client.search(FHIR::MedicationStatement, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (!entry.resource.medicationReference.nil? || !entry.resource.medicationCodeableConcept.nil?), "MedicationStatement was missing a medication reference or codeable concept"
        end
      end

      # TODO: Medication and Prescriber - need to handle references
      ['code', 'identifier', 'status', 'dateWritten'].each do |field|

        test "AS4006_#{field}", "Search for MedicationOrder by #{field}" do
          metadata {
            links "#{REST_SPEC_LINK}#search"
            links "#{BASE_SPEC_LINK}/MedicationOrder.html"
            validates resource: "MedicationOrder", methods: ["search"]
          }

          resources = getResources(FHIR::MedicationOrder)

          match_target = resources.select {|r| r.resource.respond_to?(field.to_sym) && !r.resource.send(field).nil?}.first
          search_string = match_target.resource.send(field) unless match_target.nil?
          case field
          when 'code'
            begin
              match_target = resources.select {|r| !r.resource.medicationCodeableConcept.nil?}.first
              coding = match_target.resource.medicationCodeableConcept.coding.first
              search_string = "#{coding.system}|#{coding.code}"
            rescue
              assert false, "could not get a code to search on"
            end
          when 'identifier'
            search_string = search_string.first.value unless search_string.blank? 
          end

          warning {assert !search_string.blank? && !match_target.nil?, "could not get a MedicationOrder with a #{field} value to search on"}
          if search_string.blank? || match_target.nil?
            skip
          end

          options = {
            :search => {
              :flag => false,
              :compartment => nil,
              :parameters => {
                field.downcase => search_string
              }
            }
          }
          reply = @client.search(FHIR::MedicationOrder, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          assert reply.resource, "Search did not return any MedicationOrders for #{field.downcase} => #{search_string}, should have matched Medication Order id: #{match_target.resource.xmlId}"
          assert (reply.resource.entry && reply.resource.entry.length > 0), "Search did not return any MedicationOrders for #{field.downcase} => #{search_string}, should have matched Medication Order id: #{match_target.resource.xmlId}"
          assert getIdList(reply.resource).select {|id| id == match_target.resource.xmlId}.length > 0, "Search did not find the expected MedicationOrder with ID: #{match_target.resource.xmlId}"
        end

      end

      ['code', 'identifier', 'status', 'effectivedate'].each do |field|

        test "AS4007_#{field}", "Search for MedicationStatement by #{field}" do
          metadata {
            links "#{REST_SPEC_LINK}#search"
            links "#{BASE_SPEC_LINK}/MedicationStatement.html"
            validates resource: "MedicationStatement", methods: ["search"]
          }

          resources = getResources(FHIR::MedicationStatement)

          match_target = resources.select {|r| r.resource.respond_to?(field.to_sym) && !r.resource.send(field).nil?}.first
          search_string = match_target.resource.send(field) unless match_target.nil?
          case field
          when 'code'
            begin
              match_target = resources.select {|r| !r.resource.medicationCodeableConcept.nil?}.first
              coding = match_target.resource.medicationCodeableConcept.coding.first
              search_string = "#{coding.system}|#{coding.code}"
            rescue
              assert false, "could not get a code to search on"
            end
          when 'identifier'
            search_string = search_string.first.value unless search_string.blank? 
          end

          warning {assert !search_string.blank? && !match_target.nil?, "could not get a MedicationStatement with a #{field} value to search on"}
          if search_string.blank? || match_target.nil?
            skip
          end

          options = {
            :search => {
              :flag => false,
              :compartment => nil,
              :parameters => {
                field.downcase => search_string
              }
            }
          }
          reply = @client.search(FHIR::MedicationStatement, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          assert reply.resource, "Search did not return any MedicationStatements for #{field.downcase} => #{search_string}, should have matched Medication Order id: #{match_target.resource.xmlId}"
          assert (reply.resource.entry && reply.resource.entry.length > 0), "Search did not return any MedicationStatements for #{field.downcase} => #{search_string}, should have matched Medication Order id: #{match_target.resource.xmlId}"
          assert getIdList(reply.resource).select {|id| id == match_target.resource.xmlId}.length > 0, "Search did not find the expected MedicationStatements with ID: #{match_target.resource.xmlId}"
        end

      end


      def getResources(type)

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

        reply = @client.search(type, options)

        return reply.resource.entry if (reply.resource && reply.resource.entry && reply.resource.entry.length > 0)

        options = {
          :id => patient_id,
          :search => {
            :flag => false,
            :compartment => type.to_s.demodulize,
            :parameters => nil
          }
        }

        reply = @client.search(FHIR::Patient, options)

        return reply.resource.entry if (reply.resource && reply.resource.entry && reply.resource.entry.length > 0)

        return []

      end

      def getIdList(bundle)
        return [] unless bundle.entry
        bundle.entry.map do |entry|
          if (entry.fullUrl)
            FHIR::ResourceAddress.pull_out_id(entry.resourceType, entry.fullUrl)
          elsif entry.resource
            entry.resource.xmlId
          else
            nil
          end
        end
      end
    end
  end
end
