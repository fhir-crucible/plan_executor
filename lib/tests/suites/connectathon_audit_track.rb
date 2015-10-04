module Crucible
  module Tests
    class ConnectathonAuditEventAndProvenanceTrackTest < BaseSuite

      def id
        'ConnectathonAuditEventAndProvenanceTrackTest'
      end

      def description
        'Connectathon AuditEvent and Provenance Track Test focuses on server-created AuditEvents and Provenance resources.'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient.xmlId) if @patient && !@patient.xmlId.nil?
        @client.destroy(FHIR::Patient, @patient1.xmlId) if @patient1 && !@patient1.xmlId.nil?
      end

      # Create a Patient then check for AuditEvent
      test 'CAEP1','Create a Patient then check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'AuditEvent', methods: ['search']
        }
        @patient = @resources.minimal_patient
        @patient.xmlId = nil # clear the identifier
        reply = @client.create(@patient)      
        assert_response_ok(reply)
        @patient.xmlId = reply.id

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'reference' => "Patient/#{@patient.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one AuditEvent for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:object).try(:reference).include?(@patient.xmlId), 'The correct AuditEvent was not returned.', reply.body)
        warning { assert_equal('110110', reply.resource.entry[0].try(:resource).try(:event).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of 110110 (Patient Record).', reply.body) }
      end

      # Create a Patient then check for Provenance
      # TODO Provenance must be provided by the client
      # separately or as a header:
      # Grahame says: "json format, in the X-Provenance header - I'll pick it up and store it after fixing the target reference (just leave target blank)"
      test 'CAEP2','Create a Patient then check for Provenance' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Provenance', methods: ['search']
        }
        @patient1 = @resources.minimal_patient
        @patient1.xmlId = nil # clear the identifier
        reply = @client.create(@patient1)      
        assert_response_ok(reply)
        @patient1.xmlId = reply.id

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient1.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Provenance for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:target).try(:reference).include?(@patient1.xmlId), 'The correct Provenance was not returned.', reply.body)
      end

      # Update a Patient and check for AuditEvent
      test 'CAEP3','Update a Patient then check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','update']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['update']
          validates resource: 'AuditEvent', methods: ['search']
        }
        @patient.gender = 'male'
        reply = @client.update(@patient,@patient.xmlId)      
        assert_response_ok(reply)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'reference' => "Patient/#{@patient.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.size, 'There should be two AuditEvents for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:object).try(:reference).include?(@patient.xmlId), 'An incorrect AuditEvent was returned.', reply.body)
          warning { assert_equal('110110', entry.try(:resource).try(:event).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of 110110 (Patient Record).', reply.body) }
        end
      end

      # Update a Patient and check for Provenance
      test 'CAEP4','Update a Patient then check for Provenance' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','update']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['update']
          validates resource: 'Provenance', methods: ['search']
        }
        @patient1.gender = 'male'
        reply = @client.update(@patient1,@patient1.xmlId)      
        assert_response_ok(reply)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient1.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.size, 'There should be two Provenance resources for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:target).try(:reference).include?(@patient1.xmlId), 'An incorrect Provenance was returned.', reply.body)
        end
      end

      # Read a Patient and check for AuditEvent
      test 'CAEP5','Read a Patient and check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','read']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['read']
          validates resource: 'AuditEvent', methods: ['search']
        }
        reply = @client.read(FHIR::Patient,@patient.xmlId)      
        assert_response_ok(reply)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'reference' => "Patient/#{@patient.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(3, reply.resource.entry.size, 'There should be three AuditEvents for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:object).try(:reference).include?(@patient.xmlId), 'An incorrect AuditEvent was returned.', reply.body)
          warning { assert_equal('110110', entry.try(:resource).try(:event).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of 110110 (Patient Record).', reply.body) }
        end
      end

    end
  end
end
