
module Crucible
  module Tests
    class PatientTransferTest < BaseTest

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
          # links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          # requires resource: "Patient", methods: ["create", "update", "delete"]
          # validates resource: "Patient", methods: ["history-instance"]
        }

        @patient = @resources.example_patient
        result = @client.create(@patient)
        # assert the response was good on creation
        read = @client.read(FHIR::Patient, result.resource.xmlId)
        read_resource = read.resource
        read_resource.xmlId = nil
        create_result = @client2.create(read_resource)
        read_client2 = @client2.read(FHIR::Patient, create_result.id)

        assert_response_ok result
        assert false, "failing_string"

        # check all this stuff with asserts

      end

      test 'I02','Transfer Patient between servers with id' do
      end

      # can add any function I need here to help with tests 
      # Util type functions

    end
  end
end