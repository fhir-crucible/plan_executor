module Crucible
  class FHIRStructure
  	def self.get
	    root = File.expand_path File.join('..','..'), File.dirname(File.absolute_path(__FILE__))
	    JSON.parse(File.read(File.join(root, 'lib', 'FHIR_structure.json')))
  	end
  end
end