module Crucible
  module Tests
    class DataAccessFrameworkProfilesTest < BaseSuite

      def id
        'DataAccessFrameworkProfilesTest'
      end

      def description
        'Test support for the U.S. Data Access Framework (DAF) Implementation Guide'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('argonaut')
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        @server_side_resources = {}
        @resources = Crucible::Generator::Resources.new
        @daf_conformance = @resources.daf_conformance

        # Try to create a DAF patient on the server.
        # This will facilitate SEARCH testing, if it succeeds.
        # Do not assert that the creation worked, because CREATE is *not*
        # required by DAF. This is a read-only test.
        @daf_patient = Crucible::Tests::DAFResourceGenerator.daf_patient
        reply = @client.create(@daf_patient)
        @daf_patient.xmlId = reply.id if !reply.id.nil?
        # assert_response_created(reply)
      end

      def teardown
        # delete resources
        @client.destroy(FHIR::Patient, @daf_patient.xmlId) if @daf_patient && !@daf_patient.xmlId.nil?
      end

      # Check Conformance for DAF Profiles
      test 'DAF00','Check Conformance for DAF Profiles' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        @conformance = @client.conformanceStatement

        # Collect the list of DAF profiles
        daf_profiles = @daf_conformance.profile.map{|x|x.reference}

        # Check that the conformance declares support for all the DAF profiles
        root_profiles = @conformance.profile.map{|x|x.try(:reference)}.compact
        rest_profiles = @conformance.rest.map{|r|r.resource.map{|r|r.try(:profile).try(:reference)}}.flatten.compact

        missing_daf_profiles = daf_profiles - root_profiles - rest_profiles
        assert(missing_daf_profiles.compact.empty?, "The Conformance statement does not declare support for the following DAF profiles: #{missing_daf_profiles}", @conformance.to_xml)
      end

      # Check Conformance for SMART Security Extensions
      test 'DAF01','Check Conformance for SMART-on-FHIR Security Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        smart_security_base = 'http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris'
        smart_security_extensions = ['register','authorize','token']

        @rest_index = nil
        @found_smart_code = false 
        found_smart_base = false

        @conformance.rest.each_with_index do |rest,index|
          service = rest.try(:security).try(:service)
          if !service.nil? && !service.empty?
            service.each do |concept|
              concept.coding.each do |coding|
                @found_smart_code = (!coding.nil? && coding.code=='SMART-on-FHIR' && coding.system=='http://hl7.org/fhir/restful-security-service')
                if @found_smart_code
                  @rest_index = index
                  rest.security.extension.each do |x|
                    found_smart_base = (x.url == smart_security_base)
                    if found_smart_base
                      x.extension.each do |y|
                        smart_security_extensions.delete(y.url)
                      end
                    end
                  end # each extension
                end
              end # each security code
            end
          end
        end # each restful endpoint

        assert(@found_smart_code,'Conformance does not declare the SMART-on-FHIR security service for any REST endpoints.',@conformance.to_xml)
        assert((found_smart_base && smart_security_extensions.empty?),"Conformance does not declare the SMART-on-FHIR security extensions: #{smart_security_base} #{smart_security_extensions}",@conformance.to_xml)
      end

      # Check that Conformance Resource Interactions
      test 'DAF02','Check Conformance Resource Interactions against DAF Conformance' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        @daf_conformance.rest.first.resource.each do |daf_resource|
          resource = rest.resource.select{|r|r.fhirType==daf_resource.fhirType}.first
          assert(!resource.nil?, "Server does not declare support for the #{daf_resource.fhirType} resource.")

          # TODO move rest.resource.profile checks into DAF00
          # check profile match
          warning { assert(resource.profile.reference==daf_resource.profile.reference,"Profile for #{resource.fhirType} does not match #{daf_resource.profile.reference}",resource.profile.reference) }

          # check interaction.code (and interaction.extension.valueCode for SHALL/SHOULD)
          shall_interactions = daf_resource.interaction.select{|x|x.extension.first.value.value=='SHALL'}.map{|x|x.code}
          should_interactions = daf_resource.interaction.select{|x|x.extension.first.value.value=='SHOULD'}.map{|x|x.code}

          resource.interaction.each do |interaction|
            should_interactions.delete(interaction.code)
            shall_interactions.delete(interaction.code)
          end

          warning { assert(should_interactions.empty?,"Server does not declare support for the following SHOULD interactions on #{resource.fhirType}: #{should_interactions}") }
          assert(shall_interactions.empty?,"Server does not declare support for the following SHALL interactions on #{resource.fhirType}: #{shall_interactions}")
        end
      end      

      # Check that Conformance searchParams
      test 'DAF03','Check Conformance Search Parameters against DAF Conformance' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        @daf_conformance.rest.first.resource.each do |daf_resource|
          resource = rest.resource.select{|r|r.fhirType==daf_resource.fhirType}.first
          assert(!resource.nil?, "Server does not declare support for the #{daf_resource.fhirType} resource.")

          # check searchParam.name
          shall_params = daf_resource.searchParam.select{|x|x.extension.first.value.value=='SHALL'}.map{|x|x.name}
          should_params = daf_resource.searchParam.select{|x|x.extension.first.value.value=='SHOULD'}.map{|x|x.name}

          resource.searchParam.each do |searchParam|
            should_params.delete(searchParam.name)
            shall_params.delete(searchParam.name)
          end

          warning { assert(should_params.empty?,"Server does not declare support for the following SHOULD searchParams on #{resource.fhirType}: #{should_params}") }
          assert(shall_params.empty?,"Server does not declare support for the following SHALL searchParams on #{resource.fhirType}: #{shall_params}")

          # search chains
          shall_chain = daf_resource.searchParam.select{|x|x.extension.first.value.value=='SHALL'}.map{|x|x.chain}.flatten
          should_chain = daf_resource.searchParam.select{|x|x.extension.first.value.value=='SHOULD'}.map{|x|x.chain}.flatten

          resource.searchParam.each do |searchParam|
            should_chain -= searchParam.chain
            shall_chain -= searchParam.chain
          end

          warning { assert(should_chain.empty?,"Server does not declare support for the following SHOULD searchParam.chain on #{resource.fhirType}: #{should_chain}") }
          assert(shall_chain.empty?,"Server does not declare support for the following SHALL searchParam.chain on #{resource.fhirType}: #{shall_chain}")

          # search includes
          search_includes = daf_resource.searchInclude.map(&:clone)
          search_includes -= resource.searchInclude
          assert(search_includes.empty?,"Server does not declare support for the following SHALL searchIncludes on #{resource.fhirType}: #{search_includes}")
        end
      end      

      # Check Conformance for $everything on Patient and Encounter
      test 'DAF04','Check Conformance for $everything on Patient and Encounter' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        supports_ambiguous_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('everything')}
        supports_patient_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('patient-everything')}
        supports_encounter_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('encounter-everything')}

        message = 'Excerpt from patient-operations.html#everything and encounter-operations.html#everything: In the US Realm, at a minimum, the resources returned SHALL include all the data covered by the meaningful use common data elements as defined in DAF.'

        assert((supports_patient_everything || supports_encounter_everything || supports_ambiguous_everything), message)
        warning{ assert((supports_patient_everything || supports_encounter_everything), "Ambiguous everything operation: cannot determine applicable resources. #{message}") }
        warning{ assert(supports_patient_everything, "Cannot find Patient $everything operation. #{message}")}
        warning{ assert(supports_encounter_everything, "Cannot find Encounter $everything operation. #{message}")}        
      end

      # Check Conformance for $validate operation support
      # NOT REQUIRED BY DAF IMPLEMENTATION GUIDE -- WARNING ONLY
      test 'DAF05','Optional: Check Conformance for $validate Operation Support' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        @supports_validate = rest.operation.any?{|x|['$validate','validate'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('validate')}
        message = 'Although not required by the DAF Implementation Guide, the server should support resource validation to ensure resources correctly conform to the DAF profiles.'
        warning{ assert(@supports_validate, message) }
      end

      # Check Conformance for transaction support
      # NOT REQUIRED BY DAF IMPLEMENTATION GUIDE -- WARNING ONLY
      test 'DAF06','Optional: Check Conformance for Transaction Support' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          links "#{REST_SPEC_LINK}#transaction"
          requires resource: 'Conformance', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
        }

        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        has_transaction_interaction = rest.interaction.any?{|x|x.code=='transaction'}
        has_transaction_mode = (!rest.transactionMode.nil? && rest.transactionMode!='not-supported')

        message = 'Although not required by the DAF Implementation Guide, the server should support transaction (preferred) or batch, to facilitate the transfer of patient records.'

        warning{ assert((has_transaction_interaction || has_transaction_mode), message) }
      end

      # Create DAF Profile fixtures
      # => all MUST SUPPORT fields
      # => using DAF bindings
      # => with all DAF EXTENSIONS
      # BUT THE DAF IMPLEMENTATION GUIDE DOES NOT REQUIRE CREATE/WRITE SUPPORT.
      # TRY TO VALIDATE THESE FIXTURES... BUT VALIDATE OPERATION IS NOT REQUIRED BY DAF IG EITHER.
      # TRY TO SEARCH FOR DAF PROFILED RESOURCES... AND THEN HAVE OUR CLIENT VALIDATE THEM, IF THEY EXIST.
      resources = Crucible::Generator::Resources.new
      daf_conformance = resources.daf_conformance
      daf_conformance.rest.first.resource.each do |daf_resource|

        test "DAFS0_#{daf_resource.fhirType}", "Search #{daf_resource.fhirType} for DAF-#{daf_resource.fhirType} compliant resources" do
          metadata {
            links "#{BASE_SPEC_LINK}/resource.html#profile-tags"
            links "#{BASE_SPEC_LINK}/daf/daf-#{daf_resource.fhirType.downcase}.html"
            links "#{REST_SPEC_LINK}#search"
            requires resource: "#{daf_resource.fhirType}", methods: ['search']
            validates resource: "#{daf_resource.fhirType}", methods: ['search']
          }

          klass = "FHIR::#{daf_resource.fhirType}".constantize
          options = {
            :search => {
              :parameters => {
                '_profile' => daf_resource.profile.reference
              }
            }
          }
          # search on the resource by ?_profile=
          reply = @client.search(klass,options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          warning{ assert((1 >= reply.resource.entry.size), "The server did not return any DAF-#{daf_resource.fhirType}s.") }

          if reply.resource.entry.size > 0
            # store any results to a @server_side_resources
            @server_side_resources[daf_resource.fhirType] = reply.resource.entry.map{|x|x.resource}
          end
        end

        test "DAFV0_#{daf_resource.fhirType}", "Client-side validation of DAF-#{daf_resource.fhirType} search results" do
          metadata {
            links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
            links "#{BASE_SPEC_LINK}/daf/daf-#{daf_resource.fhirType.downcase}.html"
          }
          resource = @server_side_resources[daf_resource.fhirType]
          skip if resource.nil? || resource.empty?
          
          profiles = FHIR::StructureDefinition.get_profiles_for_resource(daf_resource.fhirType)
          profile = profiles.select{|x|x.xmlId.start_with?'daf'}.first
          skip if profile.nil?

          resource.each do |r|
            assert(profile.is_valid?(r),"The #{daf_resource.fhirType} with ID #{r.xmlId} is not DAF compliant but claims to be.",r.to_xml)
          end
        end

        # if there are any profiled results in the @variable, and the server supports $validate, then $validate them
        test "DAFV1_#{daf_resource.fhirType}", "Server-side validation of DAF-#{daf_resource.fhirType} search results" do
          metadata {
            links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
            links "#{BASE_SPEC_LINK}/daf/daf-#{daf_resource.fhirType.downcase}.html"
            validates resource: "#{daf_resource.fhirType}", methods: ['$validate']
            validates profiles: ['validate-profile']
          }
          skip unless @supports_validate
          resource = @server_side_resources[daf_resource.fhirType]
          skip if resource.nil? || resource.empty?

          resource.each do |r|
            reply = @client.validate(r,{profile_uri: daf_resource.profile.reference})
            assert_response_ok(reply)
            if !reply.id.nil?
              assert( !reply.id.include?('validate'), "Server created an #{daf_resource.fhirType} with the ID `#{reply.resource.xmlId}` rather than validate the resource.", reply.id)
            end
          end
        end

      end

      # Validate invalid DAF patient
      test 'DAFV2', 'Optional: Server should not $validate an invalid DAF-Patient' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/daf/daf-patient.html"
          links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
          links "#{BASE_SPEC_LINK}/operation-resource-validate.html"
          requires resource: 'Patient', methods: ['$validate']
          validates profiles: ['validate-profile']
        }
        skip unless @supports_validate

        # Removing the identifier and adding an "animal" to the 
        # Patient violates the DAF-Patient profile.
        patient = Crucible::Tests::DAFResourceGenerator.daf_patient
        patient.identifier = nil
        patient.animal = Crucible::Tests::DAFResourceGenerator.minimal_animal

        reply = @client.validate(patient,{profile_uri: patient.meta.profile.first})
        assert_response_ok(reply)
        assert_resource_type(reply,FHIR::OperationOutcome)
        failed = reply.resource.issue.any?{|x|['fatal','error'].include?(x.severity) || x.code=='invalid' }
        assert(failed,'The server failed to reject an invalid DAF-Patient.')
      end

      # Create Invalid DAF Profile fixtures, server should reject
      # Validate valid and invalid DAF fixtures (server should PASS and FAIL appropriately)
      # Search for DAF Profile fixtures (including by using DAF extensions)

      # Test $everything on Patient and Encounter
      test 'DAF20','Test $everything on Patient' do
        metadata {
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          requires resource: 'Patient', methods: ['search', '$everything']
          validates resource: 'Patient', methods: ['search', '$everything']
        }

        resource = @server_side_resources['Patient']
        if resource.nil? || resource.empty?
          options = {
            :search => {
              :flag => nil,
              :compartment => nil,
              :parameters => nil
            }
          }
          reply = @client.search(FHIR::Patient, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          resource = reply.resource.entry.map{|x|x.resource}
        end
        skip if resource.nil? || resource.empty?

        reply = @client.fetch_patient_record(resource.first.xmlId)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test 'DAF21','Test $everything on Encounter' do
        metadata {
          links "#{BASE_SPEC_LINK}/daf/daf.html"
          links "#{BASE_SPEC_LINK}/encounter-operations.html#everything"
          requires resource: 'Encounter', methods: ['search', '$everything']
          validates resource: 'Encounter', methods: ['search', '$everything']
        }

        resource = @server_side_resources['Encounter']
        if resource.nil? || resource.empty?
          options = {
            :search => {
              :flag => nil,
              :compartment => nil,
              :parameters => nil
            }
          }
          reply = @client.search(FHIR::Encounter, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          resource = reply.resource.entry.map{|x|x.resource}
        end     
        skip if resource.nil? || resource.empty?

        reply = @client.fetch_encounter_record(resource.first.xmlId)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      # The DAF Responder SHALL identify the DAF profile(s) supported as part of the FHIR BaseResource.Meta.profile attribute for each instance.
      
    end
  end
end
