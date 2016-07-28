module Crucible
  module Tests
    class ConnectathonAuditEventAndProvenanceTrackTest < BaseSuite

      def id
        'ConnectathonAuditEventAndProvenanceTrackTest'
      end

      def description
        'Connectathon AuditEvent and Provenance Track Test focuses on server-created AuditEvents and Provenance resources.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @resources = Crucible::Generator::Resources.new
      end

      def teardown
        @client.destroy(FHIR::Provenance, @provenance1.xmlId) if @provenance1 && !@provenance1.xmlId.nil?
        @client.destroy(FHIR::Provenance, @provenance2.xmlId) if @provenance2 && !@provenance2.xmlId.nil?
        @client.destroy(FHIR::Provenance, @provenance3.xmlId) if @provenance3 && !@provenance3.xmlId.nil?
        @client.destroy(FHIR::Provenance, @provenance4.xmlId) if @provenance4 && !@provenance4.xmlId.nil?
        @client.destroy(FHIR::Patient, @patient.xmlId) if @patient && !@patient.xmlId.nil?
        @client.destroy(FHIR::Patient, @patient1.xmlId) if @patient1 && !@patient1.xmlId.nil?
        @client.destroy(FHIR::Patient, @patient2.xmlId) if @patient2 && !@patient2.xmlId.nil?
        FHIR::ResourceAddress::DEFAULTS.delete('X-Provenance') # just in case
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
          validates resource: nil, methods: ['Audit Logging', 'audit event']
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

      # Create a Patient with Provenance as a transaction
      test 'CAEP2','Create a Patient with Provenance as transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links "#{BASE_SPEC_LINK}/provenance.html#6.4.4.2" # submit as transaction
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Provenance', methods: ['search']
          validates resource: nil, methods: ['transaction-system', 'provenance']
        }

        @patient1 = @resources.minimal_patient
        @patient1.xmlId = 'foo'

        @provenance1 = FHIR::Provenance.new
        @provenance1.target = [ FHIR::Reference.new ]
        @provenance1.target[0].reference = "Patient/#{@patient1.xmlId}"
        @provenance1.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ%z")
        @provenance1.reason = [ FHIR::CodeableConcept.new ]
        @provenance1.reason[0].text = 'New patient'

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient1)
        @client.add_transaction_request('POST',nil,@provenance1)
        reply = @client.end_transaction

        # set the patient id as nil, until we know that the transaction was successful, so teardown doesn't try
        # to delete something that wasn't created
        @patient1.xmlId = nil

        assert_response_ok(reply)
        assert_bundle_response(reply)

        # set the patient id back from nil to whatever the server created
        @patient1.xmlId = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @provenance1.xmlId = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))

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
        assert(reply.resource.entry[0].try(:resource).try(:target).try(:first).try(:reference).include?(@patient1.xmlId), 'The correct Provenance was not returned.', reply.body)
      end

      # Create a Patient with a Provenance header:
      # Grahame says: "json format, in the X-Provenance header - I'll pick it up and store it after fixing the target reference (just leave target blank)"
      test 'CAEP2X','Create a Patient with X-Provenance header' do
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

        @patient2 = @resources.minimal_patient
        @patient2.xmlId = nil # clear the identifier

        @provenance2 = FHIR::Provenance.new
        @provenance2.target = [ FHIR::Reference.new ]
        # @provenance2.target[0].reference = "Patient/#{@patient2.xmlId}"
        @provenance2.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ%z")
        @provenance2.reason = [ FHIR::CodeableConcept.new ]
        @provenance2.reason[0].text = 'New patient'

        FHIR::ResourceAddress::DEFAULTS['X-Provenance'] = @provenance2.to_fhir_json
        reply = @client.create(@patient2)
        FHIR::ResourceAddress::DEFAULTS.delete('X-Provenance')

        assert_response_ok(reply)
        @patient2.xmlId = reply.id

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient2.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Provenance for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:target).try(:first).try(:reference).include?(@patient2.xmlId), 'The correct Provenance was not returned.', reply.body)
        @provenance2.xmlId = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[0].try(:response).try(:location))
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

      # Update a Patient with Provenance as a transaction
      test 'CAEP4','Update a Patient with Provenance as transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links "#{BASE_SPEC_LINK}/provenance.html#6.4.4.2" # submit as transaction
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','update']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['update']
          validates resource: 'Provenance', methods: ['search']
          validates resource: nil, methods: ['transaction-system', 'provenance']
        }
        @patient1.gender = 'male'

        @provenance3 = FHIR::Provenance.new
        @provenance3.target = [ FHIR::Reference.new ]
        @provenance3.target[0].reference = "Patient/#{@patient1.xmlId}"
        @provenance3.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ%z")
        @provenance3.reason = [ FHIR::CodeableConcept.new ]
        @provenance3.reason[0].text = 'Update Gender'

        @client.begin_transaction
        @client.add_transaction_request('PUT',nil,@patient1)
        @client.add_transaction_request('POST',nil,@provenance3)
        reply = @client.end_transaction

        assert_response_ok(reply)
        assert_bundle_response(reply)

        @provenance3.xmlId = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))

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
          assert(entry.try(:resource).try(:target).try(:first).try(:reference).include?(@patient1.xmlId), 'An incorrect Provenance was returned.', reply.body)
        end
      end

      # Update a Patient with a Provenance header:
      # Grahame says: "json format, in the X-Provenance header - I'll pick it up and store it after fixing the target reference (just leave target blank)"
      test 'CAEP4X','Update a Patient with X-Provenance header' do
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
          validates resource: nil, methods: ['provenance']
        }

        @patient2.gender = 'male'

        @provenance4 = FHIR::Provenance.new
        @provenance4.target = [ FHIR::Reference.new ]
        @provenance4.target[0].reference = "Patient/#{@patient2.xmlId}"
        @provenance4.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ%z")
        @provenance4.reason = [ FHIR::CodeableConcept.new ]
        @provenance4.reason[0].text = 'Update Gender'

        FHIR::ResourceAddress::DEFAULTS['X-Provenance'] = @provenance4.to_fhir_json
        reply = @client.update(@patient2,@patient2.xmlId)
        FHIR::ResourceAddress::DEFAULTS.delete('X-Provenance')
        assert_response_ok(reply)


        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient2.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.size, 'There should be two Provenance resources for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:target).try(:first).try(:reference).include?(@patient2.xmlId), 'An incorrect Provenance was returned.', reply.body)
        end
        @provenance3.xmlId = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[0].try(:response).try(:location))
        @provenance4.xmlId = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))
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
          validates resource: nil, methods: ['Audit Logging', 'audit event']
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
