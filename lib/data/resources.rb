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
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'patient', 'patient-example.xml'))
      end

      def example_patient_us
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'patient', 'patient-example-us-extensions.xml'))
      end

      def minimal_patient
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'patient', 'patient-minimal.xml'))
      end

      def example_patient_record_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'patient-example-f201-roel.xml'))
      end

      def example_patient_record_condition_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'condition-example-f201-fever.xml'))
      end

      def example_patient_record_condition_205
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'condition-example-f205-infection.xml'))
      end

      def example_patient_record_diagnosticreport_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'diagnosticreport-example-f201-brainct.xml'))
      end

      def example_patient_record_encounter_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'encounter-example-f201-20130404.xml'))
      end

      def example_patient_record_encounter_202
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'encounter-example-f202-20130128.xml'))
      end

      def example_patient_record_observation_202
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'observation-example-f202-temperature.xml'))
      end

      def example_patient_record_organization_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'organization-example-f201-aumc.xml'))
      end

      def example_patient_record_organization_203
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'organization-example-f203-bumc.xml'))
      end

      def example_patient_record_practitioner_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'practitioner-example-f201-ab.xml'))
      end

      def example_patient_record_procedure_201
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'record', 'procedure-example-f201-tpf.xml'))
      end

      def track3_profile
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'validation', 'observation.profile.xml'))
      end

      def track3_observations
        # get all observations in fixture_path/validation/observations
        observations = []
        files = File.join(fixture_path, 'validation', 'observations', '*.xml')
        Dir.glob(files).each do |f|
            observations << FHIR::Xml.from_xml( File.read(f) )
        end
        observations
      end

      # ------------------------------ CLAIM TEST TRACK ------------------------------

      def simple_claim
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'financial', 'claim-example-simple.xml'))
      end

      def average_claim
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'financial', 'claim-example-average.xml'))
      end

      # ------------------------------ SCHEDULING TEST TRACK ------------------------------

      def scheduling_appointment
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'appointment-simple.xml'))
      end

      def scheduling_response_patient
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'appointmentresponse-patient-simple.xml'))
      end

      def scheduling_response_practitioner
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'appointmentresponse-practitioner-simple.xml'))
      end

      def scheduling_practitioner
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'practitioner-simple.xml'))
      end

      def scheduling_schedule
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'schedule-simple.xml'))
      end

      def scheduling_slot
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'scheduling', 'slot-simple.xml'))
      end

      # ------------------------------ DAF TESTS ------------------------------

      def daf_conformance
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'daf', 'conformance-daf-query-responder.xml'))
      end

      # ------------------------------ TERMINOLOGY TRACK TESTS ------------------------------

      def codesystem_simple
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'terminology', 'codesystem-simple.xml'))
      end

      def valueset_simple
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'terminology', 'valueset-example.xml'))
      end

      def conceptmap_simple
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'terminology', 'conceptmap-example.xml'))
      end

      # ------------------------------ PATCH TRACK TESTS ------------------------------

      def medicationorder_simple
        FHIR::Xml.from_xml File.read(File.join(fixture_path, 'patch', 'medicationorder-simple.xml'))
      end

      def load_fixture(path)
        FHIR::Xml.from_xml(File.read(File.join(fixture_path, path)))
      end

    end
  end
end
