require_relative '../test_helper'

class ResourceGeneratorTest < Test::Unit::TestCase

  # Define test methods for each resource type
  FHIR::RESOURCES.each do | resourceType |    
    define_method("test_resource_generator_#{resourceType}") do
      run_generator(resourceType)
    end
  end

  def run_generator(resourceType)
    klass = Module.const_get("FHIR::#{resourceType}")
    r = Crucible::Tests::ResourceGenerator.generate(klass,3)
    assert !r.nil?, "Resource Generator could not generate #{resourceType}"
    errors = r.validate
    assert errors.empty?, "Resource Generator could not generate valid #{resourceType}\n\n#{r.to_json}\n\nERRORS: #{errors}"
  end

end
