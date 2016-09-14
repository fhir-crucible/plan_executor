require_relative '../test_helper'

class ArgonautSprint7Test < Minitest::Test

  def setup
    @fixtures = File.absolute_path(File.join(File.absolute_path(__FILE__),'..','..','fixtures'))
    @bp_observation = FHIR::Xml.from_xml File.read(File.join(@fixtures, 'vital_signs_bundle.xml'))
    @test = Crucible::Tests::ArgonautSprint7Test.new nil
    @test.instance_variable_set(:@warnings, [])
  end

  def test_validate_observation
    reply = FHIR::ClientReply.new nil, nil
    reply.resource = @bp_observation

    reply.response = Struct.new(:code).new(200)

    @test.send(:validate_observation_reply, reply)
  end

end
