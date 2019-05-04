module Crucible
  module Generator
    class Resources

      FIXTURE_DIR = File.join(File.expand_path(File.join('..','..','..'),File.absolute_path(__FILE__)), 'fixtures')

      def initialize(fhir_version = nil)
        @fhir_version = fhir_version
        @namespace = FHIR
        @namespace = FHIR::DSTU2 if @fhir_version == :dstu2
      end

      def example_patient
        load_fixture('stu3/patient/patient-example',:xml)
      end

      def example_patient_us
        load_fixture('stu3/patient/patient-example-us-extensions',:xml)
      end

      def minimal_patient
        load_fixture('stu3/patient/patient-minimal',:xml)
      end

      def example_patient_record_201
        load_fixture('stu3/record/patient-example-f201-roel',:xml)
      end

      def example_patient_record_condition_201
        load_fixture('stu3/record/condition-example-f201-fever',:xml)
      end

      def example_patient_record_condition_205
        load_fixture('stu3/record/condition-example-f205-infection',:xml)
      end

      def example_patient_record_diagnosticreport_201
        load_fixture('stu3/record/diagnosticreport-example-f201-brainct',:xml)
      end

      def example_patient_record_encounter_201
        load_fixture('stu3/record/encounter-example-f201-20130404',:xml)
      end

      def example_patient_record_encounter_202
        load_fixture('stu3/record/encounter-example-f202-20130128',:xml)
      end

      def example_patient_record_observation_202
        load_fixture('stu3/record/observation-example-f202-temperature',:xml)
      end

      def example_patient_record_organization_201
        load_fixture('stu3/record/organization-example-f201-aumc',:xml)
      end

      def example_patient_record_organization_203
        load_fixture('stu3/record/organization-example-f203-bumc',:xml)
      end

      def example_patient_record_practitioner_201
        load_fixture('stu3/record/practitioner-example-f201-ab',:xml)
      end

      def example_patient_record_procedure_201
        load_fixture('stu3/record/procedure-example-f201-tpf',:xml)
      end

      def track3_profile
        load_fixture('stu3/validation/observation.profile',:xml)
      end

      def track3_observations
        # get all observations in fixture_path/validation/observations
        observations = []
        files = File.join(fixture_path, 'validation', 'observations', '*','xml')
        Dir.glob(files).each do |f|
          observations << tag_metadata(FHIR::Xml.from_xml( File.read(f) ))
        end
        observations
      end

      # ------------------------------ CLAIM TEST TRACK ------------------------------

      def simple_claim
        load_fixture('stu3/financial/claim-example',:xml)
      end

      def average_claim
        load_fixture('stu3/financial/claim-example-oral-average',:xml)
      end

      def complex_claim
        load_fixture('stu3/financial/claim-example-oral-orthoplan',:xml)
      end

      # ------------------------------ SCHEDULING TEST TRACK ------------------------------

      def scheduling_appointment
        load_fixture('stu3/scheduling/appointment-simple',:xml)
      end

      def scheduling_response_patient
        load_fixture('stu3/scheduling/appointmentresponse-patient-simple',:xml)
      end

      def scheduling_response_practitioner
        load_fixture('stu3/scheduling/appointmentresponse-practitioner-simple',:xml)
      end

      def scheduling_practitioner
        load_fixture('stu3/scheduling/practitioner-simple',:xml)
      end

      def scheduling_schedule
        load_fixture('stu3/scheduling/schedule-simple',:xml)
      end

      def scheduling_slot
        load_fixture('stu3/scheduling/slot-simple',:xml)
      end

      # ------------------------------ US CORE TESTS ------------------------------

      def uscore_conformance
        load_fixture('stu3/uscore/CapabilityStatement-server',:json)
      end

      # ------------------------------ TERMINOLOGY TRACK TESTS ------------------------------

      def codesystem_simple
        load_fixture('stu3/terminology/codesystem-simple',:xml)
      end

      def valueset_simple
        load_fixture('stu3/terminology/valueset-example',:xml)
      end

      def conceptmap_simple
        load_fixture('stu3/terminology/conceptmap-example',:xml)
      end

      # ------------------------------ PATCH TRACK TESTS ------------------------------

      def medicationorder_simple
        load_fixture('stu3/patch/medicationrequest-simple',:xml)
      end

      # ------------------------------ CONNECTATHONS -----------------------------
      def patient_register
        load_fixture('stu3/patient/patient-register-create',:xml)
      end

      def practitioner_register
        load_fixture('stu3/practitioner/practitioner-register-create', :xml)
      end

      def eligibility_request
        load_fixture('stu3/financial/eligibilityrequest-example', :xml)
      end

      def sequence_register
        load_fixture('stu3/sequence/sequence-register-create', :xml)
      end

      def specimen_register
        load_fixture('stu3/specimen/specimen-register-create', :xml)
      end

      def observation_register
        load_fixture('stu3/observation/observation-register-create', :xml)
      end

      def patient_familyhistory
        load_fixture('stu3/patient/patient-familyhistory-create', :xml)
      end

      def observation_familyhistory
        load_fixture('stu3/observation/observation-familyhistory-create', :xml)
      end

      def family_member_history
        load_fixture('stu3/family_member_history/familymemberhistory-familyhistory-create', :xml)
      end

      def specimen_familyhistory
        load_fixture('stu3/specimen/specimen-familyhistory-create', :xml)
      end

      def diagnostic_familyhistory
        load_fixture('stu3/diagnostic_report/diagnosticreport-familyhistory-create', :xml)
      end

      def observation_datawarehouse
        load_fixture('stu3/observation/observation-datawarehouse-create', :xml)
      end

      def diagnosticreport_hltyping
        load_fixture('stu3/diagnostic_report/diagnosticreport-hlatyping-create', :xml)
      end

      def diagnosticreport_pathology
        load_fixture('stu3/diagnostic_report/diagnosticreport-pathologyreport-create', :xml)
      end

      def patient_uslab1
        load_fixture('stu3/patient/patient-uslab-example1', :xml)
      end

      def practitioner_uslab1
        load_fixture('stu3/practitioner/pract-uslab-example1', :xml)
      end

      def practitioner_uslab3
        load_fixture('stu3/practitioner/pract-uslab-example3', :xml)
      end

      def organization_uslab3
        load_fixture('stu3/organization/org-uslab-example3', :xml)
      end

      def specimen_100
        load_fixture('stu3/specimen/spec-100', :xml)
      end

      def specimen_400
        load_fixture('stu3/specimen/spec-400', :xml)
      end

      def tag_metadata(resource)
        return nil unless resource

        if resource.meta.nil?
          resource.meta = @namespace.const_get(:Meta).new({ 'tag' => [{'system'=>'http://projectcrucible.org', 'code'=>'testdata'}]})
        else
          resource.meta.tag << @namespace.const_get(:Coding).new({'system'=>'http://projectcrucible.org', 'code'=>'testdata'})
        end
        resource
      end


      def load_fixture(path, extension)

        full_path = File.join(fixture_path, "#{path}.#{extension.to_s}")
        full_path = File.join(fixture_path, "#{path}.#{@fhir_version.to_s}.#{extension}") if File.exist?(File.join("#{path}.#{@fhir_version.to_s}.#{extension}"))
        tag_metadata(@namespace.from_contents(File.read(full_path)))
      end

      private

      # FIXME: Determine a better way to share fixture data with Crucible
      def fixture_path
        if File.exists?(FIXTURE_DIR)
          FIXTURE_DIR
        else
          File.join(Rails.root, 'test', 'fixtures')
        end
      end

    end
  end
end
