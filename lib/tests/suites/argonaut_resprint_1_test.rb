module Crucible
  module Tests
    class ArgonautResprint1Test < BaseSuite
      attr_accessor :rc
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader   :canSearchById
      attr_accessor :patient_id

      def id
        'ArgonautResprint1Test'
      end

      def description
        'In Re-Sprint 1, we\'ll get up to speed on Argonaut\'s updated implementation guidance for: Patient, Allergies, and Problems & Health Concerns.'
      end

      def details
        {
          'Overview' => 'Since the Argonaut Implementation Program began in 2015, we\'ve come a long way. We\'ve gained early implementation experience working with FHIR DSTU2 and the Data Access Framework profiles — and we\'ve produced updated guidance based on this experience. We\'re running a series of "Re-Sprints" with three goals: ensure we have a chance to battle-test our latest "best practices" in time for MU3; help existing Argonaut implementers come up to speed; and provide an easy on-ramp for new Argonaut implementers.',
          'Instructions' => 'If you\'re working on a server, please complete the "servers" tab of the Sprints Spreadsheet. You\'ll need to update the status flag to indicate whether you\'ve begun work (or completed work), so clients will know when to start testing. You\'ll also share details about how a developer can obtain OAuth client credentials (client_id for public apps, or a client_id and client_secret for confidential apps) as well as user login credentials. You might consider simply sharing a set of fixed credentials in this spreadsheet, or else directing users to a web page where they can complete self-service registration. If absolutely necessary, you can ask developers to e-mail you directly. If you\'re working on a client, please complete the "clients" tab of the Sprints Spreadsheet. You\'ll also need to update the status flag to indicate whether you\'ve begun work (or completed work).',
          'FHIR API Calls' => 'For this sprint, EHRs should focus on the following FHIR Resources: Patient, AllergyIntolerance, and Condition. Patients should be retrieveable by ID, and should be searchable by demographics such as name, gender and birthdate. AllergyIntolerances should be searchable by the associated Patient ID. Conditions should be retrievable by code, where code is in the Problem valueset, and should be searchable by Patient ID as well.'
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

      test 'ARS101', 'Get patient by ID' do
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

        skip if !@patient_id

        reply = @client.read(FHIR::DSTU2::Patient, @patient_id)
        assert_response_ok(reply)
        assert_equal @patient_id, reply.id, 'Server returned wrong patient.'
        @patient = reply.resource
        assert @patient, "could not get patient by id: #{@patient_id}"
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'ARS102', 'Search by identifier' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        get_patient_by_param(:identifier => @patient[:identifier].first.try(:value))
      end

      test 'ARS103', 'Identifier without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        get_patient_by_param({ :identifier => @patient[:identifier].first.try(:value) }, false)
      end

      test 'ARS104', 'Search by Family & Given' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        family = @patient[:name].first.try(:family).try(:first)
        given = @patient[:name].first.try(:given).try(:first)
        assert family, "Patient family name not returned"
        assert given, "Patient given name not returned"
        get_patient_by_param(family: family, given: given)
      end

      test 'ARS105', 'Family & Given without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        family = @patient[:name].first.try(:family).try(:first)
        given = @patient[:name].first.try(:given).try(:first)
        assert family, "Patient family name not provided"
        assert given, "Patient given name not provided"
        get_patient_by_param({ family: family, given: given }, false)
      end

      test 'ARS106', 'Search by name and gender' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        name = @patient[:name].first.try(:family).try(:first)
        gender = @patient[:gender]
        assert name, "Patient name not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(name: name, gender: gender)
      end

      test 'ARS107', 'Name and gender without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        name = @patient[:name].first.try(:family).try(:first)
        gender = @patient[:gender]
        assert name, "Patient name not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(name: name, gender: gender)
      end

      test 'ARS108', 'Search by Birthdate' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        birthdate = @patient[:birthDate]
        gender = @patient[:gender]
        assert birthdate, "Patient birthdate not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(birthdate: birthdate, gender: gender)
      end

      test 'ARS109', 'Birthdate without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        birthdate = @patient[:birthDate]
        gender = @patient[:gender]
        assert birthdate, "Patient birthdate not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param({ birthdate: birthdate, gender: gender }, false)
      end

      test 'ARS110', 'GET AllergyIntolerance with Patient IDs' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'Patient', methods: ['read', 'search']
          requires resource: 'AllergyIntolerance', methods: ['read', 'search']
          validates resource: 'Patient', methods: ['read', 'search']
          validates resource: 'AllergyIntolerance', methods: ['read', 'search']
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @patient.xmlId

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::AllergyIntolerance, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on AllergyIntolerance does not match patient requested"
          assert entry.resource.substance, "No substance defined for AllergyIntolerance"
          entry.resource.substance.coding.each do |coding|
            warn { assert ['http://rxnav.nlm.nih.gov/REST/Ndfrt', 'http://snomed.info/sct', 'http://www.nlm.nih.gov/research/umls/rxnorm'].include?(coding.system), "Code system #{coding.system} does not match expected code system for Allergy substance coding" }
          end
          assert @status_codes.include?(entry.resource.status), 'Allergy Status is not part of status Value Set'
        end
      end

      test 'ARS111', 'GET Condition with Patient IDs' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          requires resource: "Patient", methods: ["read", "search"]
          validates resource: "Patient", methods: ["read", "search"]
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @patient.xmlId

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: {
              patient: patient_id
            }
          }
        }

        reply = @client.search(FHIR::DSTU2::Condition, options)

        assert_response_ok(reply)

        reply.resource.entry.each do |entry|
          assert (entry.resource.patient && entry.resource.patient.reference.include?(patient_id)), "Patient on condition does not match patient requested"
          entry.resource.code.coding.each do |coding|
            warn { assert coding.system == "http://snomed.info/sct", "Condition Code System is not SNOMED-CT" }
            assert !coding.code.empty?, "No code defined for Coding"
          end
        end
      end

      private

      def get_patient_by_param(params = {}, flag = true)
        assert !params.empty?, "No params for patient"
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => params
          }
        }
        reply = @client.search(@rc, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.get_by_id(@patient_id).equals?(@patient, ['_id', "text", "meta", "lastUpdated"]), 'Server returned wrong patient.'
      end

      def define_metadata(method)
        links "#{REST_SPEC_LINK}##{method}"
        links "#{BASE_SPEC_LINK}/#{@rc.name.demodulize.downcase}.html"
        requires resource: @rc.name.demodulize, methods: [method]
        validates resource: @rc.name.demodulize, methods: [method]
      end

    end
  end
end
