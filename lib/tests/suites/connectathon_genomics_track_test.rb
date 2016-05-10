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

        patient = @resources.load_fixture("patient/patient-register-create.xml")
        practitioner = @resources.load_fixture("practitioner/practitioner-register-create.xml")

        create_object(patient, :patient)
        create_object(practitioner, :practitioner)
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
          requires resource: 'Specimen', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          validates resource: 'Sequence', methods: ['create']
          validates resource: 'Specimen', methods: ['create']
          validates resource: 'Observation', methods: ['create']

          sequence = @resources.load_fixture('sequence/sequence-register-create.xml')
          specimen = @resources.load_fixture('specimen/specimen-register-create.xml')
          observation = @resources.load_fixture('observation/observation-register-create.xml')

          specimen.subject = @records[:patient].to_reference
          specimen.subject.collector = @records[:practitioner].to_reference
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
