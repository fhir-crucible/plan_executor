require_relative '../test_helper'

class FixturesTest < Test::Unit::TestCase

  fixtures = File.join('fixtures','**','*.xml')

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

    r = FHIR::Xml.from_xml(xml)
    assert(!r.nil?,"XML fixture does not deserialize.")
    
    valid = FHIR::Xml.is_valid?(xml)
    assert(valid,"XML fixture does not conform to schema.")

    # TODO Add StructureDefinition validation.
  end

end
