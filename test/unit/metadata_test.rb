require_relative '../test_helper'

class MetadataTest < Test::Unit::TestCase

  # Test gathering metadata for all the Suites
  def test_suite_list
    metadata = Crucible::Tests::SuiteEngine.list_all(true)
    assert !metadata.blank?, 'Failed to gather SuiteEngine metadata.'
  end

  # Test gathering metadata for all the TestScripts
  def test_testscript_list
    metadata = Crucible::Tests::TestScriptEngine.list_all(true)
    assert !metadata.blank?, 'Failed to gather TestScriptEngine metadata.'
  end

  # Test gathering metadata for all the tests via the Executor
  def test_executor_list
    metadata = Crucible::Tests::Executor.list_all(false, true)
    assert !metadata.blank?, 'Failed to gather Suite & TestScript metadata.'
  end

  # Test gathering metadata for a specific test by its key
  def test_suite_collect_metadata
    executor = Crucible::Tests::Executor.new(nil, nil)
    read_test = executor.find_test('ReadTest')
    assert !read_test.nil?, 'Could not find ReadTest Suite'
    metadata = executor.extract_metadata_from_test('ReadTest')
    FHIR.logger.debug JSON.pretty_generate(metadata)
    assert !metadata.blank?, 'Failed to retrieve ReadTest Suite metadata'
  end

  def test_testscript_find
    tests = Crucible::Tests::TestScriptEngine.list_all
    assert !tests.blank?, "Failed to list testscripts."

    testscript_engine = Crucible::Tests::TestScriptEngine.new(nil)

    keyed_test = testscript_engine.find_test('TS-testscript-example')
    assert !keyed_test.nil?, "Failed to find testscript by key"
  end

end
