module Crucible
  module Tests
    class ReadTest < BaseTest

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
          links 'http://hl7.org/implement/standards/FHIR-Develop/http.html#read'
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        reply = @client.read(FHIR::Patient, @id)
        assert_response_ok(reply)
        assert_equal @id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      # [SprinklerTest("R002", "Read unknown resource type")]
      test 'R002', 'Read unknown resource type.' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/http.html#read'
          links 'http://hl7.org/implement/standards/FHIR-Develop/http.html#update'
        }

        reply = @client.read(Crucible::Tests::ReadTest, @id)
        assert_response_not_found(reply)
      end

      # [SprinklerTest("R003", "Read non-existing resource id")]
      test 'R003', 'Read non-existing resource id.' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/http.html#read'
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        reply = @client.read(FHIR::Patient, 'Supercalifragilisticexpialidocious')
        assert_response_not_found(reply)
      end

      # [SprinklerTest("R004", "Read bad formatted resource id")]
      test 'R004', 'Read invalid format resource id' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/http.html#read'
          links 'http://hl7.org/implement/standards/FHIR-Develop/datatypes.html#id'
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        reply = @client.read(FHIR::Patient, 'Invalid-ID-Because_Of_!@$Special_Characters_and_Length_Over_Sixty_Four_Characters')
        assert_response_bad(reply)
      end

    end
  end
end