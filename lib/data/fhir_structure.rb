module Crucible
  class FHIRStructure
    def self.get(fhir_version = :r4)
      root = File.expand_path File.join('..','..'), File.dirname(File.absolute_path(__FILE__))
      JSON.parse(File.read(File.join(root, 'lib', "FHIR_structure_#{fhir_version.to_s}.json")))
    end
  end
end
