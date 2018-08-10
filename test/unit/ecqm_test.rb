require_relative '../test_helper'
require 'webmock'

# this is a unit test for running my testscript

class TestScriptECQMTest < Test::Unit::TestCase
	include WebMock::API

  def initialize(name = nil)
   super(name)
  end


  def test_my_testscript
    # create a TestScriptEngine
    # find my testScript
    # stub out and put all the expected things for each network call in the test script
    # execute it
  end
end