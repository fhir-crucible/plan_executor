
module Crucible
  module Tests
    class PatientTransferTest < BaseSuite

      def id
        'MultiServerPatientTransfer001'
      end

      def description
        'Crucible test for transferring a patient from one server to another'
      end

      def multiserver
        true
      end


      def setup
      	# need to extract data here before you run the test
        @resources = Crucible::Generator::Resources.new

      end

      test 'I01','Transfer Patient between servers without id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: "Patient", methods: ["create", "read"]
          validates resource: "Patient", methods: ["create", "read"]
        }

        @patient = @resources.example_patient

        client1_patient = create_and_read_patient(@patient, @client)

        # clear the ID, there is a separate test to test preserved ids
        client1_id = client1_patient.xmlId
        client1_patient.xmlId = nil

        client2_patient = create_and_read_patient(client1_patient, @client2)

        mismatch = client1_patient.mismatch client2_patient, ['_id', 'xmlId', 'versionId', 'div', 'lastUpdated']
        assert mismatch.empty?, "The transfered patient did not match the original for the following fields: #{mismatch}"

        mismatch = client1_patient.mismatch client2_patient, ['_id', 'xmlId', 'versionId']
        warning {assert mismatch.empty?, "The transfered patient did not match the original in the narrative section"}

      end

      def create_and_read_patient(patient, client)
        result = client.create(patient)
        assert_response_ok result

        read = client.read(FHIR::Patient, result.id)
        assert_response_ok read
        read.resource
      end

      test 'I02','Transfer Patient between servers with id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: "Patient", methods: ["create", "read"]
          validates resource: "Patient", methods: ["create", "read"]
        }

        @patient = @resources.example_patient

        client1_patient = create_and_read_patient(@patient, @client)
        client2_patient = create_and_read_patient(client1_patient, @client2)
        assert client1_patient.xmlId == client2_patient.xmlId, "could not transfer the patient maintaining the ID"
      end


    end
  end
end
