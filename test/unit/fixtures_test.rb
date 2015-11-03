require_relative '../test_helper'

class FixturesTest < Test::Unit::TestCase

  fixtures = File.join('fixtures','**','*.xml')

  loading = true
  t = Thread.new { FHIR::StructureDefinition.load_definitions; loading = false }

  print 'Loading StructuredDefinitions'
  while loading do
    print '.'
    sleep(10)
  end
  print " done.\n"

  # Define test methods to validate example JSON
  Dir.glob(fixtures).each do | file |    
    basename = File.basename(file,'.xml')
    xml = File.open(file, 'r:bom|UTF-8', &:read)

    define_method("test_fixture_validation_#{basename}") do
      run_validate(file,xml)
    end
  end

  def run_validate(file,xml)
    assert(file && xml)

    r = FHIR::Resource.from_contents(xml)
    # assert(r.valid?,"#{r.errors.messages}")

    root_element = Nokogiri::XML(xml).root.try(:name)      
    definition = FHIR::StructureDefinition.get_base_definition(root_element)
    assert(definition)
    
    valid = definition.is_valid?(xml,'XML')
    assert(valid,"XML fixture does not conform to definition: #{definition.name}")

    resource = FHIR::Resource.from_contents(xml)
    valid = definition.is_valid?(resource)
    assert(valid,"Resource does not conform to definition: #{definition.name}")    
  end

end
