require_relative '../test_helper'

# Simple test that verifies that we can inflate/to_xml/to_fhir_josn our fixtures
class FixturesTest < Test::Unit::TestCase

  FIXTURES = {}

  def test_a_loading_fixtures
    resources = Crucible::Generator::Resources.new

    # fixtures/patient

    @patient_example_updated = resources.load_fixture("/patient/patient-example-updated.xml")
    assert !@patient_example_updated.nil?, "Failed to load patient-example-updated.xml"
    assert @patient_example_updated.class==FHIR::Patient, "Failed to load patient-example-updated.xml as a FHIR::Patient"
    FIXTURES["/patient/patient-example-updated.xml"] = @patient_example_updated

    @patient_example_us_extension_us01 = resources.example_patient_us
    assert !@patient_example_us_extension_us01.nil?, "Failed to load patient-example-us-extension(us01).xml"
    FIXTURES["/patient/patient-example-us-extensions(us01).xml"] = @patient_example_us_extension_us01

    @patient_example = resources.example_patient
    assert !@patient_example.nil?, "Failed to load patient-example.xml"
    FIXTURES["/patient/patient-example.xml"] = @patient_example

    @patient_format_example = resources.example_format_patient
    assert !@patient_example.nil?, "Failed to load patient-format-example.xml"
    FIXTURES["/patient/patient-format-example.xml"] = @patient_format_example

    @patient_minimal = resources.load_fixture("/patient/patient-minimal.xml")
    assert !@patient_minimal.nil?, "Failed to load patient-minimal.xml"
    assert @patient_minimal.class==FHIR::Patient, "Failed to load patient-minimal.xml as a FHIR::Patient"
    FIXTURES["/patient/patient-minimal.xml"] = @patient_minimal

    # fixtures/record

    @condition_example_f201_fever = resources.example_patient_record_condition_201
    assert !@condition_example_f201_fever.nil?, "Failed to load condition-example-f201-fever.xml"
    FIXTURES["/record/condition-example-f201-fever.xml"] = @condition_example_f201_fever

    @condition_example_f205_infection = resources.example_patient_record_condition_205
    assert !@condition_example_f205_infection.nil?, "Failed to load condition-example-f205-infection.xml"
    FIXTURES["/record/condition-example-f205-infection.xml"] = @condition_example_f205_infection

    @diagnosticreport_example_f201_brainct = resources.example_patient_record_diagnosticreport_201
    assert !@diagnosticreport_example_f201_brainct.nil?, "Failed to load diagnosticreport-example-f201-brainct.xml"
    FIXTURES["/record/diagnosticreport-example-f201-brainct.xml"] = @diagnosticreport_example_f201_brainct

    @encounter_example_f201_20130404 = resources.example_patient_record_encounter_201
    assert !@encounter_example_f201_20130404.nil?, "Failed to load encounter-example-f201-20130404.xml"
    FIXTURES["/record/encounter-example-f201-20130404.xml"] = @encounter_example_f201_20130404

    @encounter_example_f202_20130128 = resources.example_patient_record_encounter_202
    assert !@encounter_example_f202_20130128.nil?, "Failed to load encounter-example-f202-20130128.xml"
    FIXTURES["/record/encounter-example-f202-20130128.xml"] = @encounter_example_f202_20130128

    @observation_example_f202_temperature = resources.example_patient_record_observation_202
    assert !@observation_example_f202_temperature.nil?, "Failed to load observation-example-f202-temperature.xml"
    FIXTURES["/record/observation-example-f202-temperature.xml"] = @observation_example_f202_temperature

    @organization_example_f201_aumc = resources.example_patient_record_organization_201
    assert !@organization_example_f201_aumc.nil?, "Failed to load organization-example-f201-aumc.xml"
    FIXTURES["/record/organization-example-f201-aumc.xml"] = @organization_example_f201_aumc

    @organization_example_f203_bumc = resources.example_patient_record_organization_203
    assert !@organization_example_f203_bumc.nil?, "Failed to load organization-example-f203-bumc.xml"
    FIXTURES["/record/organization-example-f203-bumc.xml"] = @organization_example_f203_bumc

    @patient_example_f201_roel = resources.example_patient_record_201
    assert !@patient_example_f201_roel.nil?, "Failed to load patient-example-f201-roel.xml"
    FIXTURES["/record/patient-example-f201-roel.xml"] = @patient_example_f201_roel

    @practitioner_example_f201_ab = resources.example_patient_record_practitioner_201
    assert !@practitioner_example_f201_ab.nil?, "Failed to load practitioner-example-f201-ab.xml"
    FIXTURES["/record/practitioner-example-f201-ab.xml"] = @practitioner_example_f201_ab

    @procedure_example_f201_tpf = resources.example_patient_record_procedure_201
    assert !@procedure_example_f201_tpf.nil?, "Failed to load procedure-example-f201-tpf.xml"
    FIXTURES["/record/procedure-example-f201-tpf.xml"] = @procedure_example_f201_tpf

    # fixtures/validation/observations

    @observations = resources.track3_observations
    assert !@observations.nil?, "Failed to load Track 3 Observations"

    @observation_example = @observations.first
    assert !@observation_example.nil?, "Failed to load observation-example(example).xml"
    FIXTURES["/validation/observations/observation-example(example).xml"] = @observation_example

    # fixtures/validation

    @observation_profile = resources.track3_profile
    assert !@observation_profile.nil?, "Failed to load observation.profile.xml"
    FIXTURES["/validation/observation.profile.xml"] = @observation_profile

    # patient_example = resources.load_fixture("/patient/patient-example.xml")
    # assert !patient_example.nil?, "Failed to load patient-example.xml"
  end

  def test_b_to_xml_fixtures
    puts "\tfixture.to_xml"
    FIXTURES.each do |path, fixture|
      begin
        fixture_xml = fixture.to_xml
      rescue => e
        assert !fixture_xml.nil?, "Failed to serialize #{path} to XML via to_xml! #{e.message}"
      end
      assert !fixture_xml.blank?, "Empty XML found when using to_xml on #{path}!"
      puts "\t\tSUCCESS\t#{fixture.class}\t#{path}"
    end
  end

  def test_c_to_fhir_json_fixtures
    puts "\tfixture.to_fhir_json"
    FIXTURES.each do |path, fixture|
      begin
        fixture_fhir_json = fixture.to_fhir_json
      rescue => e
        assert !fixture_fhir_json.nil?, "Failed to serialize #{path} to FHIR JSON via to_fhir_json! #{e.message}"
      end
      assert !fixture_fhir_json.blank?, "Empty FHIR JSON found when using to_fhir_json on #{path}!"
      puts "\t\tSUCCESS\t#{fixture.class}\t#{path}"
    end
  end

  # TODO: Add StructuredDefinition validation for each fixture

end
