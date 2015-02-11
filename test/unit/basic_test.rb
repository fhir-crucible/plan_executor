require_relative '../test_helper'

class BasicTest < Test::Unit::TestCase

  TESTING_ENDPOINT = 'http://fhir.healthintersections.com.au/open'

  def test_suite_list
    executor = Crucible::Tests::Executor
    tests = executor.list_all
    puts tests.keys.count
    assert !tests.blank?, "Failed to list tests."
  end

  def test_testscript_list
    tests = Crucible::Tests::TestScriptEngine.list_all
    assert !tests.blank?, "Failed to list testscripts."

    testscript_engine = Crucible::Tests::TestScriptEngine.new(nil)

    keyed_test = testscript_engine.find_test('example')
    assert !keyed_test.nil?, "Failed to find testscript by key"

    results = keyed_test.execute
    assert !results.nil? && !results.blank?, "Failed to execute testscript"
  end

end
