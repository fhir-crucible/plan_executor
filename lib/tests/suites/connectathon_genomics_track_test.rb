module Crucible
  module Tests
    class ConnectathonGenomicsTrackTest < BaseSuite

      def id
        'ConnectathonGenomicsTrackTest'
      end

      def description
        'Genomic data are of increasing importance to clinical care and secondary analysis. FHIR Genomics consists of the Sequence resource and several profiles built on top of existing FHIR resources.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @records = {}

        patient = @resources.minimal_patient
        patient.id = nil
        create_object(patient, :patient)
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
      end

      # Find Practitioner's schedule
      test 'CGT01','Register a New Sequence and Observation' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/sequence.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Sequence', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          validates resource: 'Sequence', methods: ['create']
          validates resource: 'Observation', methods: ['create']
        }
        

      end

      private

      def create_object(obj, obj_sym)
        reply = @client.create obj
        assert_response_ok(reply)
        obj.id = reply.id
        @records[obj_sym] = obj

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

    end
  end
end
