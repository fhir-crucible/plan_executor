module Crucible
  module Tests
    class ConnectathonCarePlanTrackTest < BaseSuite

      def id
        'Connectathon Care Plan Track'
      end

      def description
        'This track is intended to advance the maturity of FHIR resources for care planning: CarePlan, CareTeam, Goal, Condition, and others'
      end

      def setup
        @resources = Crucible::Tests::ResourceGenerator
        @records = {}

        patient = @resources.generate(FHIR::Patient, 3)
        create_object(patient, :patient)

        @num_care_plans = rand(5..10)

        @num_care_plans.times do |t|
          care_plan = @resources.generate(FHIR::CarePlan, 3)
          care_plan.subject = patient.to_reference
          create_object(care_plan, "care_plan_#{t}")
        end
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      test 'CCPT1','Search for all Care Plans for a Patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201701_Care_Plan#Search_for_all_Care_Plans_for_a_patient'
          requires resource: 'Patient', methods: ['create', 'read']
          requires resource: 'CarePlan', methods: ['create', 'read']
          validates resource: 'CarePlan', methods: ['create', 'read']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'patient' => @records[:patient].id
            }
          }
        }

        reply = @client.search(FHIR::CarePlan, options)
        assert_response_ok(reply)

        assert_equal reply.resource.entry.count, @num_care_plans

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals? @records[:patient].to_reference
        end
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
