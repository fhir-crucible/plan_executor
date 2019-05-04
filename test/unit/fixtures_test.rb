require_relative '../test_helper'

class FixturesTest < Test::Unit::TestCase

  ERROR_DIR = File.join('tmp', 'errors', 'FixturesTest')
  # Create a blank folder for the errors
  FileUtils.rm_rf(ERROR_DIR) if File.directory?(ERROR_DIR)
  FileUtils.mkdir_p ERROR_DIR

  fixtures = File.join('fixtures','**','*.xml')
  json_fixtures = File.join('fixtures','**','*.json')
  raise 'No Fixture Files Found' if Dir[fixtures].empty? && Dir[json_fixtures].empty?

  # Define test methods to validate example JSON
  Dir.glob(fixtures).each do | file |    
    basename = File.basename(file,'.xml')
    next if basename.start_with?('ccda')

    version = file.match(/fixtures\/([^\/]+)/)[1]
    xml = File.open(file, 'r:bom|UTF-8', &:read)

    define_method("test_fixture_validation_#{basename}_#{version}") do
      run_validate(basename, xml, version.to_sym)
    end
  end
  Dir.glob(json_fixtures).each do | file |
    basename = File.basename(file,'.json')
    json = File.open(file, 'r:bom|UTF-8', &:read)

    version = file.match(/fixtures\/([^\/]+)/)[1]
    define_method("test_json_fixture_validation_#{basename}_#{version}") do
      run_json_validate(basename, json, version.to_sym)
    end
  end

  def xml_namespace(fhir_version)
    namespace = FHIR::Xml
    if !fhir_version.nil? && FHIR.constants.include?(fhir_version.upcase)
      namespace = FHIR.const_get(fhir_version.upcase)::Xml
    end
    namespace
  end

  def json_namespace(fhir_version)
    namespace = FHIR::Json
    if !fhir_version.nil? && FHIR.constants.include?(fhir_version.upcase)
      namespace = FHIR.const_get(fhir_version.upcase)::Json
    end
    namespace
  end

  def run_validate(fixture, xml, version)
    assert(fixture && xml)
    xml_namespace = xml_namespace(version)

    r = xml_namespace.from_xml(xml)
    assert(!r.nil?,"XML fixture does not deserialize.")
    
    errors = xml_namespace.validate(xml)
    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.err", 'w:UTF-8') do |file|
        file.write "#{version}_#{fixture}: #{errors.length} errors\n\n"
        errors.each do |error|
          file.write(sprintf("%-8d  %s\n", error.line, error.message))
        end
      end
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.xml", 'w:UTF-8') { |file| file.write(xml) }
    end

    assert(errors.empty?,"XML fixture does not conform to schema.")
  end

  def run_json_validate(fixture,json,version)
    assert(fixture && json)

    json_namespace = json_namespace(version)

    r = json_namespace.from_json(json)
    assert(!r.nil?,"JSON fixture does not deserialize.")

    errors = r.validate
    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.err", 'w:UTF-8') do |file|
        file.write "#{version}_#{fixture}: #{errors.length} errors\n\n"
        errors.each do |error|
          file.write(sprintf("%-8d  %s\n", error.line, error.message))
        end
      end
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.json", 'w:UTF-8') { |file| file.write(json) }
    end

    assert(errors.empty?,"JSON fixture does not conform to definition.")
  end

end
