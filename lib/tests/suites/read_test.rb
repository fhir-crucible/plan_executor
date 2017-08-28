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
        # try to find a patient
        begin
          response = @client.read_feed(get_resource(:Patient))
          @patient = response.resource.entry.first.resource
        rescue
          # try to create a patient
          begin
            @patient = get_resource(:Patient).new(meta: { tag: [{ system: 'http://projectcrucible.org', code: 'testdata'}] }, name: { family: 'Emerald', given: 'Caro' })
            @patient_created = true
          rescue
            @patient = nil
          end
        end
      end

      def teardown
        ignore_client_exception { @patient.destroy if @patient_created }
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      test 'R001', 'Result headers on normal read.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }
        skip 'Patient not created in setup.' if @patient.nil?
        
        patient = get_resource(:Patient).read(@patient.id)

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

        ignore_client_exception { FHIR::Model.read('1') } #not a valid model
        assert(([400,404].include?(@client.reply.code)), "An unknown resource type should be 404 or 400. The spec says 404 for an unknown resource, but does not define unknown type. Returned #{@client.reply.code}." )
      end

      # [SprinklerTest("R003", "Read non-existing resource id")]
      test 'R003', 'Read non-existing resource id.' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }

        ignore_client_exception { get_resource(:Patient).read('Supercalifragilisticexpialidocious') }
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

        ignore_client_exception { get_resource(:Patient).read('Invalid-ID-Because_Of_!@$Special_Characters_and_Length_Over_Sixty_Four_Characters') }
        assert(([400,404].include?(@client.reply.code)), "Expecting 400 since invalid id, or 404 since unknown resource.  Returned #{@client.reply.code}." )
      end

      test 'R005', 'Read _summary=text' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/datatypes.html#id"
          links "#{BASE_SPEC_LINK}/resource.html#id"
          requires resource: "Patient", methods: ["create", "read", "delete"]
          validates resource: "Patient", methods: ["read"]
        }
        skip 'Patient not created in setup.' if @patient.nil?

        @summary_patient = nil
        ignore_client_exception { @summary_patient = get_resource(:Patient).read_with_summary(@patient.id, "text") }
        assert(@summary_patient != nil, 'Patient resource type not returned.')
        assert(@summary_patient.text, 'Requested summary narrative was not provided.', @client.reply.body)
      end      

    end
  end
end
