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
        FHIR::Patient.from_xml File.read(File.join(fixture_path, 'patient', 'patient-example.xml'))
      end

      def example_format_patient
        FHIR::Patient.from_xml File.read(File.join(fixture_path, 'patient', 'patient-format-example.xml'))
      end

      def example_patient_us
        FHIR::Patient.from_xml File.read(File.join(fixture_path, 'patient', 'patient-example-us-extensions(us01).xml'))
      end

      def example_patient_record_201
        FHIR::Patient.from_xml File.read(File.join(fixture_path, 'record', 'patient-example-f201-roel.xml'))
      end

      def example_patient_record_condition_201
        FHIR::Condition.from_xml File.read(File.join(fixture_path, 'record', 'condition-example-f201-fever.xml'))
      end

      def example_patient_record_condition_205
        FHIR::Condition.from_xml File.read(File.join(fixture_path, 'record', 'condition-example-f205-infection.xml'))
      end

      def example_patient_record_diagnosticreport_201
        FHIR::DiagnosticReport.from_xml File.read(File.join(fixture_path, 'record', 'diagnosticreport-example-f201-brainct.xml'))
      end

      def example_patient_record_encounter_201
        FHIR::Encounter.from_xml File.read(File.join(fixture_path, 'record', 'encounter-example-f201-20130404.xml'))
      end

      def example_patient_record_encounter_202
        FHIR::Encounter.from_xml File.read(File.join(fixture_path, 'record', 'encounter-example-f202-20130128.xml'))
      end

      def example_patient_record_observation_202
        FHIR::Observation.from_xml File.read(File.join(fixture_path, 'record', 'observation-example-f202-temperature.xml'))
      end

      def example_patient_record_organization_201
        FHIR::Organization.from_xml File.read(File.join(fixture_path, 'record', 'organization-example-f201-aumc.xml'))
      end

      def example_patient_record_organization_203
        FHIR::Organization.from_xml File.read(File.join(fixture_path, 'record', 'organization-example-f203-bumc.xml'))
      end

      def example_patient_record_practitioner_201
        FHIR::Practitioner.from_xml File.read(File.join(fixture_path, 'record', 'practitioner-example-f201-ab.xml'))
      end

      def example_patient_record_procedure_201
        FHIR::Procedure.from_xml File.read(File.join(fixture_path, 'record', 'procedure-example-f201-tpf.xml'))
      end

      def track3_profile
        FHIR::StructureDefinition.from_xml File.read(File.join(fixture_path, 'validation', 'observation.profile.xml'))
      end

      def track3_observations
        # get all observations in fixture_path/validation/observations
        observations = []
        files = File.join(fixture_path, 'validation', 'observations', '*.xml')
        Dir.glob(files).each do |f|
            observations << FHIR::Observation.from_xml( File.read(f) )
        end
        observations
      end

      def load_fixture(path)
        FHIR::Resource.from_contents(File.read(File.join(fixture_path, path)))
      end

    end
  end
end
