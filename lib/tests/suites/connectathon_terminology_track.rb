module Crucible
  module Tests
    class ConnectathonTerminologyTrackTest < BaseSuite

      def id
        'ConnectathonTerminologyTrackTest'
      end

      def description
        'Connectathon Terminology Track focuses on the $expand, $validate-code, $lookup, and $translate operations.'
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
      end

      def teardown
        # not required
      end

      ['GET','POST'].each do |how|  

        test "CT01#{how[0]}", "Expand a specific ValueSet (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#expand"
            validates resource: 'ValueSet', methods: ['$expand']
          }
          skip if @valueset.nil?
          options = {
            :id => @valueset.xmlId,
            :operation => {
              :method => how
            }
          }
          reply = @client.value_set_expansion(options)
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::ValueSet)
          check_expansion_for_concepts(reply.resource)
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
                'context' => { type: 'Uri', value: 'http://hl7.org/fhir/StructureDefinition/StructureDefinition#StructureDefinition.constrainedType' }
              }
            }
          }
          reply = @client.value_set_expansion(options)
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::ValueSet)
          check_expansion_for_concepts(reply.resource)
        end

        test "CT03#{how[0]}", "Validate a code (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$validate-code']
          }
          options = {
            :operation => {
              :method => how,
              :parameters => {
                'code' => { type: 'Code', value: 'female' },
                'system' => { type: 'Uri', value: 'http://hl7.org/fhir/ValueSet/administrative-gender' }
              }
            }
          }
          reply = @client.value_set_code_validation(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'result','valueBoolean','true')
        end

        # validate v2 code
        test "CT04#{how[0]}", "Validate a v2 code (#{how})" do
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

        # lookup a v2 code
        test "CT05#{how[0]}", "Lookup a v2 code (#{how})" do
          metadata {
            links "#{BASE_SPEC_LINK}/operations.html#executing"
            links "#{BASE_SPEC_LINK}/valueset-operations.html#validate-code"
            validates resource: 'ValueSet', methods: ['$lookup']
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
          reply = @client.value_set_code_lookup(options)
          assert_response_ok(reply)
          check_response_params(reply.body,'display','valueString','Burn')
        end

      end # ['GET','POST'].each

      def check_expansion_for_concepts(vs)
        assert(vs.expansion,'ValueSet should contain expansion.')
        assert(vs.expansion.contains,'ValueSet.expansion.contains elements are missing.')

        concepts = vs.expansion.contains.map{|c|c.code}

        expansion_missing = FHIR::ElementDefinition::TypeRefComponent::VALID_CODES[:code] - concepts
        expansion_added = concepts - FHIR::ElementDefinition::TypeRefComponent::VALID_CODES[:code]

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
            assert(e.value==value,"Output parameters do not contain #{name}=#{value}")
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
