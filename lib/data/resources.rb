module Crucible
  module Generator
    class Resources

      FIXTURE_DIR = File.join('fixtures')

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

      def example_patient_us
        FHIR::Patient.from_xml File.read(File.join(fixture_path, 'patient', 'patient-example-us-extensions(us01).xml'))
      end

    end
  end
end