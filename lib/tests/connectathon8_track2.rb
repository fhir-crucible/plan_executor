module Crucible
  module Tests
    class TrackTwoTest < BaseTest

      def id
        'Connectathon8Track2'
      end

      def description
        'Connectathon 8 Track 2 Tests'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient_record_201
        @condition_1 = @resources.example_patient_record_condition_201
        @condition_2 = @resources.example_patient_record_condition_205
        @diagnosticreport = @resources.example_patient_record_diagnosticreport_201
        @encounter_1 = @resources.example_patient_record_encounter_201
        @encounter_2 = @resources.example_patient_record_encounter_202
        @observation = @resources.example_patient_record_observation_202
        @organization_1 = @resources.example_patient_record_organization_201
        @organization_2 = @resources.example_patient_record_organization_203
        @practitioner = @resources.example_patient_record_practitioner_201
        @procedure = @resources.example_patient_record_procedure_201
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient_id) if !@patient_id.nil?
        @client.destroy(FHIR::Organization, @org1_reply.id) if !@org1_id.nil?
        @client.destroy(FHIR::Organization, @org2_reply.id) if !@org2_id.nil?
        @client.destroy(FHIR::Practitioner, @prac_reply.id) if !@prac_id.nil?
        @client.destroy(FHIR::Patient, @pat_reply.id) if !@pat_id.nil?
        @client.destroy(FHIR::Condition, @cond2_reply.id) if !@cond2_id.nil?
        @client.destroy(FHIR::Observation, @obs_reply.id) if !@obs_id.nil?
        @client.destroy(FHIR::DiagnosticReport, @dr_reply.id) if !@dr_id.nil?
        @client.destroy(FHIR::Encounter, @enc1_reply.id) if !@enc1_id.nil?
        @client.destroy(FHIR::Encounter, @enc2_reply.id) if !@enc2_id.nil?
        @client.destroy(FHIR::Procedure, @prc_reply.id) if !@prc_id.nil?
        @client.destroy(FHIR::Condition, @cond1_reply.id) if !@cond1_id.nil?
      end

      #
      # Test if the general Fetch Patient Record operation is supported
      #
      test 'C8T2.1A', 'Fetch all patient records' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.fetch_patient_record

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      #
      # Test if the general Fetch Patient Record operation and start/end parameters are supported
      #
      test 'C8T2.1B', 'Fetch all patient records with [start, end]' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.fetch_patient_record(nil, "2012-01-01", "2012-12-31")

        assert_response_ok(reply)
        assert_bundle_response(reply)

        # TODO: Determine how start/end scope all patient records (e.g., birthdate?)
        skip
      end

      #
      # Test if the specific Fetch Patient Record operation is supported
      #
      test 'C8T2.2A', 'Fetch specific patient record' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create']
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.create @patient
        @patient_id = reply.id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)
      end

      #
      # Test if the specific Fetch Patient Record operation and start/end parameters are supported
      #
      test 'C8T2.2B', 'Fetch specific patient record with [start, end]' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create']
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.create @patient
        @patient_id = reply.id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id, "2012-01-01", "2012-12-31")

        assert_response_ok(record)
        assert_bundle_response(record)

        # TODO: Determine how start/end scope a specific patient record (e.g., birthdate?)
        skip
      end

      #
      # Test if we can update parts of a specific Fetch Patient Record operation result
      #
      test 'C8T2.2C', 'Fetch specific patient record - BONUS: Update' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create', 'update']
          validates resource: 'Patient', methods: ['update', '$everything']
        }

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)

        @patient.telecom[0].value='1-234-567-8901'
        @patient.name[0].given = ["Not", "Given"]

        reply = @client.update @patient, @patient_id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)
        assert record.resource.entry[0].resource.telecom[0].value == '1-234-567-8901'
        assert record.resource.entry[0].resource.name[0].given == ['Not', 'Given']
      end

      #
      # Test if we can write and read an entire patient record
      #
      test 'C8T2.3', 'Write and then fetch an entire patient record' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://hl7.org/implement/standards/FHIR-Develop/argonauts.html'
          requires resource: 'Organization', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Condition', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'DiagnosticReport', methods: ['create']
          requires resource: 'Encounter', methods: ['create']
          requires resource: 'Procedure', methods: ['create']
          validates resource: 'Patient', methods: ['$everything']
        }

        skip # FIXME: Skip this test until unit test has stubs for these resources

        create_patient_record

        record = @client.fetch_patient_record(@pat_reply.id)

        assert_response_ok(record)
        assert_bundle_response(record)

        # TODO: Validate returned result against each example record
        skip
      end

      def create_patient_record
        @org1_reply = @client.create @organization_1
        @org1_id = @org1_reply.id
        assert_response_ok(@org1_reply)

        @org2_reply = @client.create @organization_2
        @org2_id = @org2_reply.id
        assert_response_ok(@org2_reply)

        @prac_reply = @client.create @practitioner
        @prac_id = @prac_reply.id
        assert_response_ok(@prac_reply)

        @pat_reply = @client.create @patient
        @pat_id - @pat_reply.id
        assert_response_ok(@pat_reply)

        @cond2_reply = @client.create @condition_2
        @cond2_id = @cond2_reply.id
        assert_response_ok(@cond2_reply)

        @obs_reply = @client.create @observation
        @obs_id = @obs_reply.id
        assert_response_ok(@obs_reply)

        @dr_reply = @client.create @diagnosticreport
        @dr_id = @dr_reply.id
        assert_response_ok(@dr_reply)

        @enc1_reply = @client.create @encounter_1
        @enc1_id = @enc1_reply.id
        assert_response_ok(@enc1_reply)

        @enc2_reply = @client.create @encounter_2
        @enc2_id = @enc2_reply.id
        assert_response_ok(@enc2_reply)

        @prc_reply = @client.create @procedure
        @prc_id = @prc_reply.id
        assert_response_ok(@prc_reply)

        @cond1_reply = @client.create @condition_1
        @cond1_id = @cond1_reply.id
        assert_response_ok(@cond1_reply)
      end

    end
  end
end
