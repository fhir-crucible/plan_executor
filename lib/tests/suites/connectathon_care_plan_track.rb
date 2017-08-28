module Crucible
  module Tests
    class ConnectathonCarePlanTrackTest < BaseSuite

      def id
        'Connectathon Care Plan Track'
      end

      def description
        'This track is intended to advance the maturity of FHIR resources for care planning: CarePlan, CareTeam, Goal, Condition, and others'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @resources = Crucible::Tests::ResourceGenerator
        @records = {}

        patient = @resources.generate(FHIR::Patient, 3)
        create_object(patient, "patient")

        @num_care_plans = rand(2..5)

        # Create some generic care plans, with a subject and no categories
        @num_care_plans.times do |t|
          care_plan = @resources.generate(FHIR::CarePlan, 3)
          care_plan.subject = patient.to_reference
          care_plan.category = []
          create_object(care_plan, "care_plan_#{t}")
        end

        # Create some cancer-category care plans
        @num_cancer_care_plans = rand(1..3)
        @cancer_care_plan_category = FHIR::CodeableConcept.new(text: "Cancer care plan")
        @cancer_care_plan_category.coding = FHIR::Coding.new(code: "395082007", system: "http://snomed.info/sct", display: "Cancer care plan")
        @num_cancer_care_plans.times do |t|
          care_plan = @resources.generate(FHIR::CarePlan, 3)
          care_plan.subject = patient.to_reference
          care_plan.category = [@cancer_care_plan_category]
          create_object(care_plan, "cancer_care_plan_#{t}")
        end

        # Create some care teams for a patient
        @num_care_teams = rand(1..3)
        @num_care_teams.times do |t|
          care_team = @resources.generate(FHIR::CareTeam, 3)
          care_team.subject = patient.to_reference
          create_object(care_team, "care_team_#{t}")
        end

        # Create some care teams with a specific Practitioner
        @num_practitioner_care_teams = rand(2..4)
        care_team_practitioner = @resources.generate(FHIR::Practitioner, 3)
        create_object(care_team_practitioner, "care_team_practitioner")
        @num_practitioner_care_teams.times do |t|
          care_team = @resources.generate(FHIR::CareTeam, 3)
          care_team.subject = patient.to_reference
          participant = FHIR::CareTeam::Participant.new
          participant.member = @records['care_team_practitioner'].to_reference
          care_team.participant = [participant]
          create_object(care_team, "practitioner_care_team_#{t}")
        end
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
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
              'patient' => @records["patient"].id
            }
          }
        }

        reply = @client.search(FHIR::CarePlan, options)
        assert_response_ok(reply)

        assert_equal @num_care_plans + @num_cancer_care_plans, reply.resource.entry.count

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals?(@records["patient"].to_reference), "care plan #{entry.resource.id} subject ID doesn't match given subject ID #{@records["patient"].to_reference}"
        end
      end

      test 'CCPT2','Search for all Cancer-category Care Plans for a Patient' do
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
              'patient' => @records["patient"].id,
              'category' => '395082007'
            }
          }
        }

        reply = @client.search(FHIR::CarePlan, options)
        assert_response_ok(reply)

        assert_equal @num_cancer_care_plans, reply.resource.entry.count

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals?(@records["patient"].to_reference), "care plan #{entry.resource.id} subject ID doesn't match given subject ID #{@records["patient"].to_reference}"
          assert entry.resource.category.first.coding.first.equals?(@cancer_care_plan_category.coding), "care plan category code doesn't match cancer category code #{@cancer_care_plan_category} (#{entry.resource.category.first.coding.first.mismatch(@cancer_care_plan_category.coding)})"
        end
      end

      test 'CCPT3','Search for all Care Teams for a Patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201701_Care_Plan#Search_for_all_Care_Plans_for_a_patient'
          requires resource: 'Patient', methods: ['create', 'read']
          requires resource: 'CareTeam', methods: ['create', 'read']
          validates resource: 'CareTeam', methods: ['create', 'read']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'patient' => @records["patient"].id
            }
          }
        }

        reply = @client.search(FHIR::CareTeam, options)
        assert_response_ok(reply)

        assert_equal @num_care_teams + @num_practitioner_care_teams, reply.resource.entry.count

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals?(@records["patient"].to_reference), "care team #{entry.resource.id} subject ID doesn't match given subject ID #{@records["patient"].to_reference}"
        end
      end

      test 'CCPT4','Search for all Care Teams for a given Practitioner' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201701_Care_Plan#Search_for_all_Care_Plans_for_a_patient'
          requires resource: 'Patient', methods: ['create', 'read']
          requires resource: 'Practitioner', methods: ['create', 'read']
          requires resource: 'CareTeam', methods: ['create', 'read']
          validates resource: 'CareTeam', methods: ['create', 'read']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'participant' => @records["care_team_practitioner"].to_reference.reference
            }
          }
        }

        reply = @client.search(FHIR::CareTeam, options)
        assert_response_ok(reply)

        assert_equal @num_practitioner_care_teams, reply.resource.entry.count

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals?(@records["patient"].to_reference), "care team #{entry.resource.id} subject ID doesn't match given subject ID #{@records["patient"].to_reference}"
        end
      end

      test 'CCPT4','Search for all Care Teams for a given Practitioner and Condition' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201701_Care_Plan#Search_for_all_Care_Plans_for_a_patient'
          requires resource: 'Patient', methods: ['create', 'read']
          requires resource: 'Practitioner', methods: ['create', 'read']
          requires resource: 'CareTeam', methods: ['create', 'read']
          validates resource: 'CareTeam', methods: ['create', 'read']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'participant' => @records["care_team_practitioner"].to_reference.reference
            }
          }
        }

        reply = @client.search(FHIR::CareTeam, options)
        assert_response_ok(reply)

        assert_equal @num_practitioner_care_teams, reply.resource.entry.count

        reply.resource.entry.each do |entry|
          assert entry.resource.subject.equals?(@records["patient"].to_reference), "care team #{entry.resource.id} subject ID doesn't match given subject ID #{@records["patient"].to_reference}"
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
