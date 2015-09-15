module Crucible
  module Tests
    class ReadTest < BaseSuite

      def id
        'ReadTest'
      end

      def description
        'Initial Sprinkler tests (R001, R002, R003, R004) for testing basic READ requests.'
      end

      def setup
        @patient = ReadTest.createPatient('Emerald', 'Caro')
        reply = @client.create(@patient)
        @id = reply.id
        @body = reply.body
      end

      def teardown
        @client.destroy(FHIR::Patient, @id)
      end

      def self.createPatient(family, given)
        patient = FHIR::Patient.new(name: [FHIR::HumanName.new(family: [family], given: [given])])
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      test 'R001', 'Result headers on normal read.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        assert(@id, 'Setup was unable to create a patient.',@body)
        reply = @client.read(FHIR::Patient, @id)
        assert_response_ok(reply)
        assert_equal @id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      # [SprinklerTest("R002", "Read unknown resource type")]
      test 'R002', 'Read unknown resource type.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#update"
        }

        reply = @client.read(Crucible::Tests::ReadTest, @id)
        assert_response_not_found(reply)
      end

      # [SprinklerTest("R003", "Read non-existing resource id")]
      test 'R003', 'Read non-existing resource id.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        reply = @client.read(FHIR::Patient, 'Supercalifragilisticexpialidocious')
        assert_response_not_found(reply)
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

        reply = @client.read(FHIR::Patient, 'Invalid-ID-Because_Of_!@$Special_Characters_and_Length_Over_Sixty_Four_Characters')
        assert_response_bad(reply)
      end

      test 'R005', 'Read _summary=text' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/datatypes.html#id"
          links "#{BASE_SPEC_LINK}/resource.html#id"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        assert(@id, 'Setup was unable to create a patient.', @body)
        reply = @client.read(FHIR::Patient, @id, @client.default_format, 'text')
        assert_response_ok(reply)
        assert(reply.try(:resource).try(:text), 'Requested summary narrative was not provided.', reply.body)
      end      

    end
  end
end
