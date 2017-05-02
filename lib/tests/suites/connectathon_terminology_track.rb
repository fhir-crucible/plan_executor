module Crucible
  module Tests
    class ConnectathonTerminologyTrackTest < BaseSuite

      def id
        'ConnectathonTerminologyTrackTest'
      end

      def description
        'Connectathon Terminology Track focuses on the $expand, $validate-code, $lookup, and $translate operations.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        # find FHIRDefinedType valueset
        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'name' => 'FHIRDefinedType'
            }
          }
        }
        @valueset = nil
        reply = @client.search(FHIR::ValueSet, options)
        if reply.code==200 && !reply.resource.nil?
          bundle = reply.resource
          @valueset = bundle.entry[0].resource if bundle.entry.size > 0
        end

        @resources = Crucible::Generator::Resources.new

        if @valueset.nil?
          # The resource was not found, try to create it in case the server
          # dynamically calculates terminology operations based on local resources
          codesystem_types = @resources.load_fixture('terminology/codesystem-data-types.json')
          codesystem_rsrcs = @resources.load_fixture('terminology/codesystem-resource-types.json')
          valueset_defined = @resources.load_fixture('terminology/valueset-defined-types.json')

          @codesystem_types_id = @client.create(codesystem_types).id
          @codesystem_rsrcs_id = @client.create(codesystem_rsrcs).id
          @valueset_defined_id = @client.create(valueset_defined).id
          @valueset_defined.id = @valueset_defined_id
          @valueset = valueset_defined
          
        end

        v2_codesystem = @resources.load_fixture('terminology/v2-codesystem.json')
        v2_valueset = @resources.load_fixture('terminology/v2-valueset.json')
        @v2_codesystem_id = @client.create(v2_codesystem).id
        @v2_valueset_id = @client.create(v2_valueset).id
      end

      def teardown
        @client.destroy(FHIR::ValueSet, @valueset_defined_id) if @valueset_defined_id
        @client.destroy(FHIR::CodeSystem, @codesystem_types_id) if @codesystem_types_id
        @client.destroy(FHIR::CodeSystem, @codesystem_rsrcs_id) if @codesystem_rsrcs_id
        @client.destroy(FHIR::ValueSet, @v2_valueset_id) if @v2_valueset_id
        @client.destroy(FHIR::CodeSystem, @v2_codesystem_id) if @v2_codesystem_id
        # CT13 does # DELETE codesystem_simple
        # CT13 does # DELETE valueset_simple
        # CT17 does # DELETE conceptmap_created_id
      end

      ['GET','POST'].each do |how|

        test "CT01#{how[0]}", "Expand a specific ValueSet (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#expand"
            validates resource: 'ValueSet', methods: ['$expand']
          }
          skip 'Valueset not created in setup.' if @valueset.nil?
          options = {
            :id => @valueset.id,
            :operation => {
              :method => how
            }
          }
          reply = @client.value_set_expansion(options)
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::ValueSet)
          reference_set = FHIR::StructureDefinition::METADATA['type']['valid_codes'].values.flatten
          check_expansion_for_concepts(reply.resource, reference_set)
        end

        test "CT02#{how[0]}", "Expand a ValueSet by context (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#expand"
            validates resource: 'ValueSet', methods: ['$expand']
          }
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'context' => { type: 'Uri', value: 'http://hl7.org/fhir/StructureDefinition/StructureDefinition#StructureDefinition.type' }
              }
            }
          }
          reply = @client.value_set_expansion(options)
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::ValueSet)
          reference_set = FHIR::StructureDefinition::METADATA['type']['valid_codes'].values.flatten
          check_expansion_for_concepts(reply.resource, reference_set)
        end

        test "CT03#{how[0]}", "Validate a code using identifier (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          skip 'Valueset not created in setup.' if @valueset.nil?
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'identifier' => { type: 'Uri', value: 'http://hl7.org/fhir/ValueSet/data-types' },
                'code' => { type: 'Code', value: 'base64Binary' },
                'system' => { type: 'Uri', value: 'http://hl7.org/fhir/data-types' }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end

        # validate v2 code
        test "CT04#{how[0]}", "Validate a v2 code using identifier (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: 'BRN' },
                'system' => { type: 'Uri', value: 'http://hl7.org/fhir/v2/0487' },
                'identifier' => { type: 'Uri', value: 'http://hl7.org/fhir/ValueSet/v2-0487' }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end

        test "CT06#{how[0]}", "Validate a code by system (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: 'base64Binary' },
                'system' => { type: 'Uri', value: 'http://hl7.org/fhir/data-types' }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end

        # validate v2 code
        test "CT07#{how[0]}", "Validate a v2 code by system (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: 'BRN' },
                'system' => { type: 'Uri', value: 'http://hl7.org/fhir/v2/0487' }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end
      end # ['GET','POST'].each

      test "CT09", "Create a ValueSet that points to a local CodeSystem" do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/codesystem.html"
          links "#{BASE_SPEC_LINK}/valueset.html#create"
          validates resource: 'CodeSystem', methods: ['create']
          validates resource: 'ValueSet', methods: ['create']
        }

        @resources = Crucible::Generator::Resources.new
        @codesystem_simple = @resources.codesystem_simple
        @valueset_simple = @resources.valueset_simple

        # make more unique in case this valueset & codesystem already exists
        @valueset_simple.url = @valueset_simple.url + rand(10000000).to_s
        @codesystem_simple.url = @codesystem_simple.url + rand(10000000).to_s
        @valueset_simple.compose.include.first.system = @codesystem_simple.url

        reply = @client.create @codesystem_simple
        assert_response_code(reply, 201)
        @codesystem_created_id = reply.id
        reply = @client.create @valueset_simple
        assert_response_code(reply, 201)
        @valueset_created_id = reply.id
      end

      ['GET','POST'].each do |how|

        test "CT10#{how[0]}", "Expand a ValueSet that points to a local CodeSystem(#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#expand"
            validates resource: 'ValueSet', methods: ['$expand']
          }
          skip 'ValueSet not created in setup.' if @valueset_created_id.nil?
          skip 'CodeSystem not created in CT09.' if @codesystem_created_id.nil?
          options = {
            :id => @valueset_created_id,
            :operation => {
              :method => how
            }
          }
          reply = @client.value_set_expansion(options)
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::ValueSet)
          reference_set = @codesystem_simple.concept.map(&:code)
          check_expansion_for_concepts(reply.resource, reference_set)
        end

        test "CT11#{how[0]}", "Validate a code from local CodeSystem using identifier(#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          skip 'ValueSet not created in setup.' if @valueset_created_id.nil?
          skip 'CodeSystem not created in CT09.' if @codesystem_created_id.nil?
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: @codesystem_simple.concept.first.code },
                'system' => { type: 'Uri', value: @codesystem_simple.url },
                'identifier' => { type: 'Uri', value: @valueset_simple.url }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end

        test "CT12#{how[0]}", "Lookup code from local CodeSystem using identifier(#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/codesystem-operations.html#lookup"
            validates resource: 'ValueSet', methods: ['$lookup']
          }
          skip 'CodeSystem not created in CT09.' if @codesystem_created_id.nil?
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: @codesystem_simple.concept.first.code },
                'system' => { type: 'Uri', value: @codesystem_simple.url }
              }
            }
          }
          reply = @client.code_system_lookup(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'display','valueString',@codesystem_simple.concept.first.display)
        end
      end

      test "CT13", "Delete CodeSystem and ValueSet" do
        metadata {
          links "#{REST_SPEC_LINK}#delete"
          links "#{BASE_SPEC_LINK}/valueset.html"
          links "#{BASE_SPEC_LINK}/codesystem.html"
          validates resource: 'CodeSystem', methods: ['delete']
          validates resource: 'ValueSet', methods: ['delete']
        }

        skip 'CodeSystem not created in CT09.' if @codesystem_created_id.nil?
        reply = @client.destroy FHIR::CodeSystem, @codesystem_created_id
        assert_response_code(reply, 204)

        skip if @valueset_created_id.nil?
        @client.destroy FHIR::ValueSet, @valueset_created_id
        assert_response_code(reply, 204)
      end

      test "CT14", "Create ConceptMap" do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/conceptmap.html"
          validates resource: 'ConceptMap', methods: ['create']
        }

        @resources = Crucible::Generator::Resources.new
        @conceptmap_simple = @resources.conceptmap_simple
        @conceptmap_simple.id = nil
        @conceptmap_simple.url = @conceptmap_simple.url + rand(10000000).to_s

        reply = @client.create @conceptmap_simple
        assert_response_code(reply, 201)
        @conceptmap_created_id = reply.id
      end

      ['GET','POST'].each do |how|
        test "CT15#{how[0]}", "$translate a code using a ConceptMap (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/conceptmap-operations.html#translate"
            validates resource: 'ConceptMap', methods: ['$translate']
          }
          skip 'ConceptMap not created in test CT14.' if @conceptmap_created_id.nil?
          assert @conceptmap_simple.group.first.try(:element).try(:first), "ConceptMap #{@conceptmap_simple.id} does not have a code to translate in group"
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: @conceptmap_simple.group.first.element.first.code },
                'system' => { type: 'Uri', value: @conceptmap_simple.group.first.source },
                'target' => { type: 'Uri', value: @conceptmap_simple.targetUri}
              }
            }
          }
          reply = @client.concept_map_translate(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end
      end

      test "CT16", "$closure table maintenance" do
        metadata {
          links "#{BASE_SPEC_LINK}/operations.html#executing"
          links "#{BASE_SPEC_LINK}/conceptmap-operations.html#closure"
          validates resource: 'ConceptMap', methods: ['$closure']
        }
        coding = FHIR::Coding.new({'system'=>'http://snomed.info/sct','code'=>'22298006'})
        options = {
          :operation => {
            :method => 'POST',
            :parameters => {
              'name' => { type: 'String', value: 'crucible-test-closure' },
              'concept' => { type: 'Coding', value: coding }
            }
          }
        }
        reply = @client.closure_table_maintenance(options)
        assert_response_ok(reply)
        assert_resource_type(reply, FHIR::ConceptMap)
        code = reply.resource.element.find{|x|x.code=='22298006'}
        assert code, 'Closure Table Operation should return the code that was supplied in the request.'
      end

      test "CT17", "Delete ConceptMap" do
        metadata {
          links "#{REST_SPEC_LINK}#delete"
          links "#{BASE_SPEC_LINK}/conceptmap.html"
          validates resource: 'ConceptMap', methods: ['delete']
        }

        skip 'ConceptMap not created in test CT14.' if @conceptmap_created_id.nil?
        reply = @client.destroy FHIR::ConceptMap, @conceptmap_created_id
        assert_response_code(reply, 204)
      end

      def check_expansion_for_concepts(vs, ref)
        assert(vs.expansion,'ValueSet should contain expansion.')
        assert(vs.expansion.contains,'ValueSet.expansion.contains elements are missing.')

        concepts = vs.expansion.contains.map{|c|c.code}

        expansion_missing = ref - concepts
        expansion_added = concepts - ref

        assert(expansion_missing.empty?,"ValueSet expansion is missing the following concepts: #{expansion_missing}")
        assert(expansion_added.empty?,"ValueSet expansion contained some unexpected concepts: #{expansion_added}")
      end

      def check_response_params(contents,name,attribute,value)
        begin
          doc = Nokogiri::XML(contents)
          if doc.errors.empty?
            doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
            doc.root.add_namespace_definition('xhtml', 'http://www.w3.org/1999/xhtml')
            e = doc.root.xpath("./fhir:parameter[fhir:name[@value=\"#{name}\"]]/fhir:#{attribute}").first
            assert(e[:value]==value,"Output parameters do not contain #{name}=#{value}")
          else
            hash = JSON.parse(contents)
            params = hash['parameter']
            p = params.select{|p|p['name']==name}.first
            assert(p[attribute]==value,"Output parameters do not contain #{name}=#{value}")
          end
        rescue Exception => e
          raise AssertionException.new 'Unable to parse response parameters', e.message
        end
      end

    end
  end
end
