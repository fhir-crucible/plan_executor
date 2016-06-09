module Crucible
  module Tests
    class ReadTest < BaseSuite

      def id
        'ReadTest'
      end

      def description
        'Initial Sprinkler tests (R001, R002, R003, R004) for testing basic READ requests.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        @patient = FHIR::Patient.create(name: { family: 'Emerald', given: 'Caro' })
      end

      def teardown
        @patient.destroy
      end

      def self.createPatient(family, given)
        patient = FHIR::Patient.new.from_hash(name: [FHIR::HumanName.new.from_hash(family: [family], given: [given])])
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      test 'R001', 'Result headers on normal read.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        patient = FHIR::Patient.read(@patient.id)

        assert_response_ok(@client.reply)
        assert_equal @patient.id, @client.reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(@client.reply) }
        warning { assert_etag_present(@client.reply) }
        warning { assert_last_modified_present(@client.reply) }
      end

      # [SprinklerTest("R002", "Read unknown resource type")]
      test 'R002', 'Read unknown resource type.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#update"
        }

        FHIR::Model.read(@patient.id) #not a valid model
        assert(([400,404].include?(@client.reply.code)), "An unknown resource type should be 404 or 400. The spec says 404 for an unknown resource, but does not define unknown type. Returned #{@client.reply.code}." )
      end

      # [SprinklerTest("R003", "Read non-existing resource id")]
      test 'R003', 'Read non-existing resource id.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        FHIR::Patient.read('Supercalifragilisticexpialidocious')
        assert_response_not_found(@client.reply)
      end

      # [SprinklerTest("R004", "Read bad formatted resource id")]
      test 'R004', 'Read invalid format resource id' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/datatypes.html#id"
          links "#{BASE_SPEC_LINK}/resource.html#id"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        FHIR::Patient.read('Invalid-ID-Because_Of_!@$Special_Characters_and_Length_Over_Sixty_Four_Characters')
        assert_response_not_found(@client.reply)
      end

      test 'R005', 'Read _summary=text' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/datatypes.html#id"
          links "#{BASE_SPEC_LINK}/resource.html#id"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        patient = FHIR::Patient.read_with_summary(@patient.id, "text")
        assert_response_ok(@client.reply)
        assert(patient.text, 'Requested summary narrative was not provided.', @client.reply.body)
      end      

    end
  end
end
