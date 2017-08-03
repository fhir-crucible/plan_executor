require_relative '../test_helper'

class ResourceGeneratorTest < Test::Unit::TestCase

  # Define test methods for each resource type
  FHIR::RESOURCES.each do | resourceType |    
    define_method("test_resource_generator_#{resourceType}") do
      run_generator(resourceType)
    end
  end

  # Also check to make sure that everything in the resource is within the DSTU2 namespace
  FHIR::DSTU2::RESOURCES.each do | resourceType |    
    define_method("test_resource_generator_dsut2_#{resourceType}") do
      resource = run_generator(resourceType, :dstu2)
      assert check_valid_namespaces(resource, 'FHIR::DSTU2'), "Resource Generator created a class of type FHIR::DSTU2::#{resourceType} that contained elements from the wrong version."
    end
  end

  def run_generator(resourceType, version = :stu3)

    klass_namespace = "FHIR"
    if version != :stu3
      klass_namespace = "FHIR::#{version.to_s.upcase}"
    end
    klass = Module.const_get("#{klass_namespace}::#{resourceType}")
    
    r = Crucible::Tests::ResourceGenerator.generate(klass,3)
    assert !r.nil?, "Resource Generator could not generate #{resourceType}"
    errors = r.validate
    assert errors.empty?, "Resource Generator could not generate valid #{resourceType}\n\n#{r.to_json}\n\nERRORS: #{errors}"

    r
  end

  def check_valid_namespaces(resource, namespace)
    return resource.all? {|v| check_valid_namespaces(v, namespace)} if resource.class.name == 'Array'
    return true unless resource.class.name.start_with?("FHIR")
    return false unless resource.class.name.start_with?(namespace)
    return resource.instance_values.values.all? { |v| check_valid_namespaces(v, namespace) }
  end

end
