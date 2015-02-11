require_relative '../test_helper'

class BasicTest < Test::Unit::TestCase

  TESTING_ENDPOINT = 'http://fhir.healthintersections.com.au/open'

  def test_suite_list
    executor = Crucible::Tests::Executor.new(nil)
    tests = executor.list_all
    puts tests.keys.count
    assert !tests.blank?, "Failed to list tests."
  end

end
