require_relative '../test_helper'

class ArgonautSprint6Test < Test::Unit::TestCase

  def setup
    @fixtures = File.absolute_path(File.join(File.absolute_path(__FILE__),'..','..','fixtures'))
    @labs = FHIR::Bundle.from_xml File.read(File.join(@fixtures, 'lab_results_bundle.xml'))
    @reports = FHIR::Bundle.from_xml File.read(File.join(@fixtures, 'diagnostic_bundle.xml'))
    @test = Crucible::Tests::ArgonautSprint6Test.new nil
    @test.instance_variable_set(:@warnings, [])
  end

  def test_validate_observation
    reply = FHIR::ClientReply.new nil, nil
    reply.resource = @labs

    reply.response = Struct.new(:code).new(200)

    @test.send(:validate_observation_reply, reply)
  end

  def test_validate_diagnostic_report
    reply = FHIR::ClientReply.new nil, nil
    reply.resource = @reports

    reply.response = Struct.new(:code).new(200)

    @test.send(:validate_diagnostic_report_reply, reply)
  end

end
