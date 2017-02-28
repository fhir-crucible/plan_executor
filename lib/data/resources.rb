module Crucible
  module Generator
    class Resources

      FIXTURE_DIR = File.join(File.expand_path(File.join('..','..','..'),File.absolute_path(__FILE__)), 'fixtures')

      # FIXME: Determine a better way to share fixture data with Crucible
      def fixture_path
        if File.exists?(FIXTURE_DIR)
          FIXTURE_DIR
        else
          File.join(Rails.root, 'test', 'fixtures')
        end
      end

      def example_patient
        load_fixture('patient/patient-example.xml')
      end

      def example_format_patient
        load_fixture('patient/patient-format-example.xml')
      end

      def example_patient_us
        load_fixture('patient/patient-example-us-extensions(us01).xml')
      end

      def minimal_patient
        load_fixture('patient/patient-minimal.xml')
      end

      def example_patient_record_201
        load_fixture('record/patient-example-f201-roel.xml')
      end

      def example_patient_record_condition_201
        load_fixture('record/condition-example-f201-fever.xml')
      end

      def example_patient_record_condition_205
        load_fixture('record/condition-example-f205-infection.xml')
      end

      def example_patient_record_diagnosticreport_201
        load_fixture('record/diagnosticreport-example-f201-brainct.xml')
      end

      def example_patient_record_encounter_201
        load_fixture('record/encounter-example-f201-20130404.xml')
      end

      def example_patient_record_encounter_202
        load_fixture('record/encounter-example-f202-20130128.xml')
      end

      def example_patient_record_observation_202
        load_fixture('record/observation-example-f202-temperature.xml')
      end

      def example_patient_record_organization_201
        load_fixture('record/organization-example-f201-aumc.xml')
      end

      def example_patient_record_organization_203
        load_fixture('record/organization-example-f203-bumc.xml')
      end

      def example_patient_record_practitioner_201
        load_fixture('record/practitioner-example-f201-ab.xml')
      end

      def example_patient_record_procedure_201
        load_fixture('record/procedure-example-f201-tpf.xml')
      end

      def track3_profile
        load_fixture('validation/observation.profile.xml')
      end

      def track3_observations
        # get all observations in fixture_path/validation/observations
        observations = []
        files = File.join(fixture_path, 'validation', 'observations', '*.xml')
        Dir.glob(files).each do |f|
            observations << tag_metadata( FHIR::Observation.from_xml( File.read(f)))
        end
        observations
      end

      # ------------------------------ CLAIM TEST TRACK ------------------------------

      def simple_claim
        load_fixture('financial/claim-example-simple.xml')
      end

      def average_claim
        load_fixture('financial/claim-example-average.xml')
      end

      # ------------------------------ SCHEDULING TEST TRACK ------------------------------

      def scheduling_appointment
        load_fixture('scheduling/appointment-simple.xml')
      end

      def scheduling_response_patient
        load_fixture('scheduling/appointmentresponse-patient-simple.xml')
      end

      def scheduling_response_practitioner
        load_fixture('scheduling/appointmentresponse-practitioner-simple.xml')
      end

      def scheduling_practitioner
        load_fixture('scheduling/practitioner-simple.xml')
      end

      def scheduling_schedule
        load_fixture('scheduling/schedule-simple.xml')
      end

      def scheduling_slot
        load_fixture('scheduling/slot-simple.xml')
      end

      # ------------------------------ DAF TESTS ------------------------------

      def daf_conformance
        load_fixture('daf/conformance-daf-query-responder.xml')
      end

      def tag_metadata(resource)
        if resource.meta.nil?
          resource.meta = FHIR::Resource::ResourceMetaComponent.new
          resource.meta.tag = [ Crucible::Tests::ResourceGenerator.minimal_coding('http://projectcrucible.org','testdata') ]
        else
          resource.meta.tag << Crucible::Tests::ResourceGenerator.minimal_coding('http://projectcrucible.org','testdata')
        end
        resource
      end

      def load_fixture(path)
        tag_metadata(FHIR::Resource.from_contents(File.read(File.join(fixture_path, path))))
      end

    end
  end
end
