require_relative '../test_helper'

class ResourceGeneratorTest < Test::Unit::TestCase

  ERROR_DIR = File.join('tmp', 'errors', 'GeneratorTest')
  # Create a blank folder for the errors
  FileUtils.rm_rf(ERROR_DIR) if File.directory?(ERROR_DIR)
  FileUtils.mkdir_p ERROR_DIR

  # Define test methods for each resource type
  # FHIR::RESOURCES.each do | resource_type |    
  #   3.times do |index|
  #     max_depth = index + 2
  #     define_method("test_resource_generator_r4_#{resource_type}_#{max_depth}") do
  #       run_generator(resource_type, :r4, max_depth )
  #     end
  #   end
  # end

  # Also check to make sure that everything in the resource is within the STU3 namespace
  FHIR::STU3::RESOURCES.each do | resource_type |    
    3.times do |index|
      max_depth = index + 2
      define_method("test_resource_generator_stu3_#{resource_type}_#{max_depth}") do
        resource = run_generator(resource_type, :stu3, max_depth)
        assert check_valid_namespaces(resource, 'FHIR::STU3'), "Resource Generator created a class of type FHIR::STU3::#{resource_type} that contained elements from the wrong version."
      end
    end
  end

  # Also check to make sure that everything in the resource is within the DSTU2 namespace
  FHIR::DSTU2::RESOURCES.each do | resource_type |    
    3.times do |index|
      max_depth = index + 2
      define_method("test_resource_generator_dsut2_#{resource_type}_#{max_depth}") do
        resource = run_generator(resource_type, :dstu2, max_depth)
        assert check_valid_namespaces(resource, 'FHIR::DSTU2'), "Resource Generator created a class of type FHIR::DSTU2::#{resource_type} that contained elements from the wrong version."
      end
    end
  end

  def run_generator(resource_type, version, max_depth)

    klass_namespace = "FHIR"
    if version != :r4
      klass_namespace = "FHIR::#{version.to_s.upcase}"
    end
    klass = Module.const_get("#{klass_namespace}::#{resource_type}")
    
    r = Crucible::Tests::ResourceGenerator.generate(klass,max_depth)
    assert !r.nil?, "Resource Generator could not generate #{resource_type} with max depth #{max_depth}"
    errors = r.validate

    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{resource_type}_#{max_depth}.err", 'w:UTF-8') do |file|
        file.write(JSON.pretty_generate(errors))
      end
      File.open("#{ERROR_DIR}/#{version}_#{resource_type}_#{max_depth}.json", 'w:UTF-8') { |file| file.write(r.to_json) }
    end

    assert errors.empty?, "Resource Generator could not generate valid #{resource_type} with max depth #{max_depth}"

    r
  end

  def check_valid_namespaces(resource, namespace)
    return resource.all? {|v| check_valid_namespaces(v, namespace)} if resource.class.name == 'Array'
    return true unless resource.class.name.start_with?("FHIR")
    return false unless resource.class.name.start_with?(namespace)
    return resource.instance_values.values.all? { |v| check_valid_namespaces(v, namespace) }
  end

  def test_valid_oid_generator
    500.times do
      random_oid = Crucible::Tests::ResourceGenerator.random_oid
      assert /urn:oid:[0-2](\.[1-9]\d*)+/.match?(random_oid), "Randomly generated #{random_oid} does not appear to be a valid oid."
    end
  end

end
