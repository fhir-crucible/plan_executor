require_relative '../test_helper'

class FHIRStructureTest < Test::Unit::TestCase

  def test_fhir_starburst_root
    structure = Crucible::FHIRStructure.get(:stu3)
    structure['name'] == 'FHIR'
  end

  def test_fhir_starburst_root_dstu2
    structure = Crucible::FHIRStructure.get(:dstu2)
    structure['name'] == 'FHIR'
  end

  def test_no_duplicate_names_in_starburst
    [:stu3, :dstu2].each do |version|
      structure = Crucible::FHIRStructure.get(version)
      names = all_names(structure)

      assert names.uniq.length == names.length
    end
  end

  def test_no_missing_resources_in_starburst

    [:stu3, :dstu2].each do |version|
      structure = Crucible::FHIRStructure.get
      resource_subset = structure['children'].select{|c| c['name'] == 'RESOURCES'}.first
      structure_resources = all_names(resource_subset, true).map{|e| e.downcase.delete(' ')}
      model_resources = FHIR::RESOURCES.map(&:downcase).reject{|m| m == 'resource' || m == "domainresource"}

      missing_resources = model_resources - structure_resources
      extra_resources = structure_resources - model_resources

      assert(missing_resources.length == 0, "Missing these resources from the FHIRStructure #{version.to_s}: #{missing_resources.join(', ')}")
      assert(extra_resources.length == 0, "Unknown resources in the FHIRStructure #{version.to_s}: #{extra_resources.join(', ')}")
    end

  end

  def test_no_unknown_requires_in_tests
    metadata = Crucible::Tests::SuiteEngine.list_all(true)
    requires_and_validates = metadata.map{|k,v| [v['validates'].map{|k2,v2| v2}, v['requires'].map{|k2,v2| v2}]}.flatten.reject(&:nil?)
    keys = requires_and_validates.map{|r| [r[:resource], r[:methods], r[:profiles], r[:extensions]]}.flatten.reject(&:nil?).uniq
    keys.map! {|k| k.downcase.delete(' ')}

    structure = Crucible::FHIRStructure.get
    names = all_names(structure).map{|e| e.downcase.delete(' ')}

    extra_keys = keys - names

    assert(extra_keys.length == 0, "Unknown keys in requires and validates: #{extra_keys.join(', ')}")

  end

  private

  def all_names(hash, leaves_only = false)

    names = []
  
    names << hash['name'] if (hash['children'].nil? || !leaves_only)

    names << hash['children'].map {|child| all_names(child, leaves_only)} unless hash["children"].nil?

    names.flatten

  end

end
