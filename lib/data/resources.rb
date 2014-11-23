module Crucible
  module Generator
    class Resources

      FIXTURE_DIR = File.join('fixtures')

      def example_patient
        FHIR::Patient.from_xml File.read(File.join(FIXTURE_DIR, 'patient', 'patient-example.xml'))
      end

    end
  end
end