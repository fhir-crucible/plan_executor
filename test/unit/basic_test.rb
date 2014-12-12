require_relative '../test_helper'

class BasicTest < Test::Unit::TestCase

  TESTING_ENDPOINT = 'http://fhir.healthintersections.com.au/open'

  def test_suite_list
    executor = Crucible::Tests::Executor
    tests = executor.list_all
    assert !tests.blank?, "Failed to list tests."
  end

end
