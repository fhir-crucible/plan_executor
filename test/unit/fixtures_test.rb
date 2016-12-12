require_relative '../test_helper'

class FixturesTest < Test::Unit::TestCase

  ERROR_DIR = File.join('tmp', 'errors', 'FixturesTest')
  # Create a blank folder for the errors
  FileUtils.rm_rf(ERROR_DIR) if File.directory?(ERROR_DIR)
  FileUtils.mkdir_p ERROR_DIR

  fixtures = File.join('fixtures','**','*.xml')
  raise 'No Fixture Files Found' if Dir[fixtures].empty?

  # Define test methods to validate example JSON
  Dir.glob(fixtures).each do | file |    
    basename = File.basename(file,'.xml')
    next if basename.start_with?('ccda')
    xml = File.open(file, 'r:bom|UTF-8', &:read)

    define_method("test_fixture_validation_#{basename}") do
      run_validate(basename,xml)
    end
  end

  def run_validate(fixture,xml)
    assert(fixture && xml)

    r = FHIR::Xml.from_xml(xml)
    assert(!r.nil?,"XML fixture does not deserialize.")
    
    errors = FHIR::Xml.validate(xml)
    if !errors.empty?
      File.open("#{ERROR_DIR}/#{fixture}.err", 'w:UTF-8') do |file|
        file.write "#{fixture}: #{errors.length} errors\n\n"
        errors.each do |error|
          file.write(sprintf("%-8d  %s\n", error.line, error.message))
        end
      end
      File.open("#{ERROR_DIR}/#{fixture}.xml", 'w:UTF-8') { |file| file.write(xml) }
    end

    assert(errors.empty?,"XML fixture does not conform to schema.")
    # TODO Add StructureDefinition validation.
  end

end
