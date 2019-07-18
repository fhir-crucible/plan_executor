require_relative '../test_helper'

class BaseTestscriptTest < Test::Unit::TestCase
  def test_collect_metadata_when_operation_is_missing_type
    testscript = FHIR::STU3::TestScript.new(id: "missing-operation-type")
    test_with_no_type_on_operation = FHIR::STU3::TestScript::Test.new
    test_action = FHIR::STU3::TestScript::Setup::Action.new
    test_action.operation = FHIR::STU3::TestScript::Setup::Action::Operation.new(resource: "Patient")
    test_with_no_type_on_operation.action = [test_action]
    testscript.test = [test_with_no_type_on_operation]

    base_testscript = Crucible::Tests::BaseTestScript.new(testscript, nil)

    assert(base_testscript.collect_metadata['missing-operation-type'][0]['validates'][0]['methods'].empty?(), "Validate methods should not include nil value when operation type is not set.")
  end
end
