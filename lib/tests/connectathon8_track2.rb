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
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient_id) if !@patient_id.nil?
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
          validates resource: 'Patient', methods: ['create', '$everything']
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
          validates resource: 'Patient', methods: ['create', '$everything']
        }

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
          validates resource: 'Patient', methods: ['create', 'update', '$everything']
        }

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)

        @patient.telecom[0].value='1-234-567-8901'
        @patient.name[0].given = ["Not","Given"]

        reply = @client.update @patient, @patient_id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)
        assert record.resource.telecom[0].value == '1-234-567-8901'
        assert record.resource.name[0].given == ['Not', 'Given']
      end

      #
      # Test if we can write and read an entire patient record
      #
      test 'C8T2.3', 'Write and then fetch an entire patient record' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://hl7.org/implement/standards/FHIR-Develop/argonauts.html'
          requires resource: 'Patient', methods: ['create']
          # TODO: Add other patient record requires
          validates resource: 'Patient', methods: ['create', '$everything']
          # TODO: Add other patient record validates
        }

        # TODO: Create each component of a patient record, preferably in correct order

        # TODO: Fetch entire patient record

        # TODO: Validate returned result against each example record

        skip
      end

    end
  end
end
