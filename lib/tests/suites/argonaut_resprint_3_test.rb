module Crucible
  module Tests
    class ArgonautResprint3Test < BaseSuite
      attr_accessor :rc
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader   :canSearchById
      attr_accessor :patient_id

      def id
        'ArgonautResprint3Test'
      end

      def description
        'In Re-Sprint 3, we\'ll get up to speed on Argonaut\'s updated implementation guidance for: Medications, Immunizations, Goals, and UDI.'
      end

      def details
        {
          'Overview' => 'Since the Argonaut Implementation Program began in 2015, we\'ve come a long way. We\'ve gained early implementation experience working with FHIR DSTU2 and the Data Access Framework profiles — and we\'ve produced updated guidance based on this experience. We\'re running a series of "Re-Sprints" with three goals: ensure we have a chance to battle-test our latest "best practices" in time for MU3; help existing Argonaut implementers come up to speed; and provide an easy on-ramp for new Argonaut implementers.',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprints Spreadsheet. You\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly. If you\'re working on a client, please complete the "clients" tab of the Sprints Spreadsheet. You\'ll also need to update the status flag to indicate whether you\'ve begun work (or completed work).',
          'FHIR API Calls' => 'For this sprint, EHRs should focus on the following FHIR Resources: MedicationStatement, MedicationOrder, Immunization, Goal, and Device'
        }
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @rc = FHIR::DSTU2::Patient
        @tags.append('argonaut')
        @category = {id: 'argonaut', title: 'Argonaut'}
        @status_codes = ['active', 'unconfirmed', 'confirmed', 'inactive', 'resolved', 'refuted', 'entered-in-error']
        @supported_versions = [:dstu2]
      end

      def setup
        if !@client.client.try(:params).nil? && @client.client.params['patient']
          @patient_id = @client.client.params['patient']
        end
      end

      test 'ARS301', 'Get patient by ID' do
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
          @patient = nil
        end

        skip unless @patient_id

        reply = @client.read(FHIR::DSTU2::Patient, @patient_id)
        assert_response_ok(reply)
        assert_equal @patient_id.to_s, reply.id.to_s, 'Server returned wrong patient.'
        @patient = reply.resource
        assert @patient, "could not get patient by id: #{@patient_id}"
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'ARS302', 'GET MedicationOrder with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "MedicationOrder", methods: ["read", "search"]
          validates resource: "MedicationOrder", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::MedicationOrder, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          med = entry.resource
          assert med.dateWritten, "MedicationOrder '#{med.xmlId}' does not have a dateWritten"
          assert med.medicationCodeableConcept || med.medicationReference, "MedicationOrder '#{med.xmlId}' does not have an embedded Medication"
          assert med.status && !med.status.empty?, "MedicationOrder '#{med.xmlId}' must have a non-blank status"
          assert med.patient.reference == "Patient/#{@patient_id}", "MedicationOrder '#{med.xmlId}' patient (#{med.patient.reference}) doesn't match the specified patient (Patient/#{@patient_id}})"
          assert med.prescriber, "MedicationOrder '#{med.xmlId}' does not have a prescriber"
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No MedicationOrders were found for patient #{@patient_id}" }
        skip unless valid_entries > 0
      end

      test 'ARS303', 'GET MedicationStatement with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "MedicationStatement", methods: ["read", "search"]
          validates resource: "MedicationStatement", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::MedicationStatement, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          # Note: haven't been able to find a server that supports MedicationStatement and has a patient with it.
          med = entry.resource
          assert med.effectiveDateTime || med.effectivePeriod, "MedicationStatement '#{med.xmlId} 'does not have an effective date or period"
          assert med.medicationCodeableConcept || med.medicationReference, "MedicationStatement '#{med.xmlId}' does not have an embedded Medication"
          assert med.status && !med.status.empty?, "MedicationStatement '#{med.xmlId}' must have a non-blank status"
          assert med.patient.reference == "Patient/#{@patient_id}", "MedicationStatement '#{med.xmlId}' patient (#{med.patient.reference}) doesn't match the specified patient (Patient/#{@patient_id}})"
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No MedicationStatements were found for patient #{@patient_id}" }
        skip unless valid_entries > 0
      end

      test 'ARS304', 'GET Immunization with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Immunization", methods: ["read", "search"]
          validates resource: "Immunization", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::Immunization, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          imm = entry.resource
          assert imm.date, "Immunization '#{imm.xmlId}' does not have an administration date"
          assert imm.status && !imm.status.empty?, "Immunization '#{imm.xmlId}' must have a non-blank status"
          assert imm.patient.reference == "Patient/#{@patient_id}", "Immunization '#{imm.xmlId}' patient (#{imm.patient.reference}) doesn't match the specified patient (Patient/#{@patient_id})"
          assert imm.wasNotGiven != nil, "Immunization '#{imm.xmlId}' does not have a boolean value in 'wasNotGiven'"
          assert imm.reported != nil, "Immunization '#{imm.xmlId}' does not have a boolean value in 'reported'"
          assert imm.vaccineCode, "Immunization '#{imm.xmlId}' does not have a code value in vaccineCode"
          #can't check whether vaccineCode is in the DAF CVX valueSet, because that valueSet has no codes in it.
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No Immunizations were found for patient #{@patient_id}" }
        skip unless valid_entries > 0
      end

      test 'ARS305', 'GET Goals with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Goal", methods: ["read", "search"]
          validates resource: "Goal", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::Goal, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          med = entry.resource
          assert med.status && !med.status.empty?, "Goal '#{med.xmlId}' must have a non-blank status"
          # array is composed of GoalStatus ValueSet codes: http://hl7.org/fhir/DSTU2/valueset-Goal-status.html
          assert %w{proposed planned accepted rejected in-progress achieved sustaining on-hold cancelled}.include?(med.status), "Goal '#{med.xmlId}' must have a status from the GoalStatus Value set at http://hl7.org/fhir/DSTU2/valueset-Goal-status.html"
          assert med.description && !med.description.empty?, "Goal '#{med.xmlId}' must have a non-blank description"
          assert med.subject.reference == "Patient/#{@patient_id}", "Goal '#{med.xmlId}' patient (#{med.subject.reference}) doesn't match the specified patient (Patient/#{@patient_id})"
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No Goals were found for patient #{@patient_id}" }
        skip unless valid_entries > 0
      end

      test 'ARS306', 'GET Goals with Patient ID and Date' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Goal", methods: ["read", "search"]
          validates resource: "Goal", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id,
              targetdate: 'ge2000-01-01'
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::Goal, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          med = entry.resource
          assert med.status && !med.status.empty?, "Goal '#{med.xmlId}' must have a non-blank status"
          # array is composed of GoalStatus ValueSet codes: http://hl7.org/fhir/DSTU2/valueset-Goal-status.html
          assert %w{proposed planned accepted rejected in-progress achieved sustaining on-hold cancelled}.include?(med.status), "Goal '#{med.xmlId}' must have a status from the GoalStatus Value set at http://hl7.org/fhir/DSTU2/valueset-Goal-status.html"
          assert med.description && !med.description.empty?, "Goal '#{med.xmlId}' must have a non-blank description"
          assert med.subject.reference == "Patient/#{@patient_id}", "Goal '#{med.xmlId}' patient (#{med.subject.reference}) doesn't match the specified patient (Patient/#{@patient_id})"
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No Goals were found for patient #{@patient_id} after Jan 1, 2000" }
        skip unless valid_entries > 0
      end

      test 'ARS307', 'GET Devices with Patient ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Device", methods: ["read", "search"]
          validates resource: "Device", methods: ["read", "search"]
        }

        skip if !@patient_id

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: @patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::Device, options)

        assert_response_ok(reply)

        valid_entries = 0

        reply.resource.entry.each do |entry|
          med = entry.resource
          assert med.fhirType && !med.fhirType.coding.empty?, "Device '#{med.xmlId}' must have a non-blank status"
          assert med.udi && !med.udi.empty?, "Device '#{med.xmlId}' must have a non-blank UDI string"
          assert med.patient.reference == "Patient/#{@patient_id}", "Device '#{med.xmlId}' patient (#{med.patient.reference}) doesn't match the specified patient (Patient/#{@patient_id})"
          valid_entries += 1
        end

        warning { assert valid_entries > 0, "No Devices were found for patient #{@patient_id}" }
        skip unless valid_entries > 0
      end
    end
  end
end
