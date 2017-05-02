module Crucible
  module Tests
    class USCoreTest < BaseSuite

      def id
        'USCoreTest'
      end

      def description
        'Test support for the U.S. Core Implementation Guide'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('argonaut')
        @tags.append('connectathon')
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        @server_side_resources = {}
        @resources = Crucible::Generator::Resources.new
        @uscore_conformance = @resources.uscore_conformance

        # Try to create a USCore patient on the server.
        # This will facilitate SEARCH testing, if it succeeds.
        # Do not assert that the creation worked, because CREATE is *not*
        # required by USCore. This is a read-only test.
        @patient = Crucible::Tests::USCoreResourceGenerator.patient
        reply = @client.create(@patient)
        @patient.id = reply.id if !reply.id.nil?
        # assert_response_created(reply)
      end

      def teardown
        # delete resources
        @client.destroy(FHIR::Patient, @patient.id) if @patient && !@patient.id.nil?
      end

      # Check CapabilityStatement for USCore Profiles
      test 'US00','Check CapabilityStatement for USCore Profiles' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        @conformance = @client.conformance_statement
        assert(@conformance, 'No capability statement found.')

        # Collect the list of USCore profiles
        profiles = @uscore_conformance.profile.map{|x|x.reference}

        # Check that the conformance declares support for all the USCore profiles
        root_profiles = @conformance.profile.map{|x|x.try(:reference)}.compact
        rest_profiles = @conformance.rest.map{|r|r.resource.map{|r|r.try(:profile).try(:reference)}}.flatten.compact

        missing_profiles = profiles - root_profiles - rest_profiles
        assert(missing_profiles.compact.empty?, "The CapabilityStatement statement does not declare support for the following USCore profiles: #{missing_profiles}", @conformance.to_xml)
      end

      # Check CapabilityStatement for SMART Security Extensions
      test 'US01','Check CapabilityStatement for SMART-on-FHIR Security Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        smart_security_base = 'http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris'
        smart_security_extensions = ['register','authorize','token']

        @rest_index = nil
        @found_smart_code = false
        found_smart_base = false

        assert(@conformance, 'No capability statement found.')
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

        assert(@found_smart_code,'CapabilityStatement does not declare the SMART-on-FHIR security service for any REST endpoints.',@conformance.to_xml)
        assert((found_smart_base && smart_security_extensions.empty?),"CapabilityStatement does not declare the SMART-on-FHIR security extensions: #{smart_security_base} #{smart_security_extensions}",@conformance.to_xml)
      end

      # Check that CapabilityStatement Resource Interactions
      test 'US02','Check CapabilityStatement Resource Interactions against USCore CapabilityStatement' do
         metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        assert(@conformance, 'No capability statement found.')
        remote_server_rest = @conformance.rest.first
        remote_server_rest = @conformance.rest[@rest_index] if @found_smart_code

        @uscore_conformance.rest.first.resource.each do |uscore_resource_element|
          us_core_profile = @uscore_conformance.profile.detect{|p| p.extension.first.valueCode==uscore_resource_element.type}.reference
          server_resource_element = remote_server_rest.resource.select{|r|r.type==uscore_resource_element.type}.first
          assert(!server_resource_element.nil?, "Server does not declare support for the #{uscore_resource_element.type} resource.")

          # check profile match
          warning { assert(server_resource_element.profile.try(:reference)==us_core_profile,"Profile for #{server_resource_element.type} does not match #{us_core_profile}",server_resource_element.profile.try(:reference)) }

          # check interaction.code (and interaction.extension.valueCode for SHALL/SHOULD)
          shall_interactions = uscore_resource_element.interaction.select{|x|x.extension.first.value=='SHALL'}.map{|x|x.code}
          should_interactions = uscore_resource_element.interaction.select{|x|x.extension.first.value=='SHOULD'}.map{|x|x.code}

          server_resource_element.interaction.each do |interaction|
            should_interactions.delete(interaction.code)
            shall_interactions.delete(interaction.code)
          end

          warning { assert(should_interactions.empty?,"Server does not declare support for the following SHOULD interactions on #{uscore_resource_element.type}: #{should_interactions}") }
          assert(shall_interactions.empty?,"Server does not declare support for the following SHALL interactions on #{uscore_resource_element.type}: #{shall_interactions}")
        end
      end

      # Check that CapabilityStatement searchParams
      test 'US03','Check CapabilityStatement Search Parameters against USCore CapabilityStatement' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        assert(@conformance, 'No capability statement found.')
        remote_server_rest = @conformance.rest.first
        remote_server_rest = @conformance.rest[@rest_index] if @found_smart_code

        @uscore_conformance.rest.first.resource.each do |uscore_resource_element|
          server_resource_element = remote_server_rest.resource.select{|r|r.type==uscore_resource_element.type}.first
          assert(!server_resource_element.nil?, "Server does not declare support for the #{uscore_resource_element.type} resource.")

          # check searchParam.name
          shall_params = uscore_resource_element.searchParam.select{|x|x.extension.first.value=='SHALL'}.map{|x|x.name}
          should_params = uscore_resource_element.searchParam.select{|x|x.extension.first.value=='SHOULD'}.map{|x|x.name}

          server_resource_element.searchParam.each do |searchParam|
            should_params.delete(searchParam.name)
            shall_params.delete(searchParam.name)
          end

          warning { assert(should_params.empty?,"Server does not declare support for the following SHOULD searchParams on #{uscore_resource_element.type}: #{should_params}") }
          assert(shall_params.empty?,"Server does not declare support for the following SHALL searchParams on #{uscore_resource_element.type}: #{shall_params}")

          # search includes
          search_includes = server_resource_element.searchInclude.map(&:clone)
          search_includes -= server_resource_element.searchInclude
          warning { assert(search_includes.empty?,"Server does not declare support for the following searchIncludes on #{uscore_resource_element.type}: #{search_includes}") }
        end
      end

      # Check CapabilityStatement for $everything on Patient and Encounter
      test 'US04','Check CapabilityStatement for $everything on Patient and Encounter' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        assert(@conformance, 'No capability statement found.')
        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        supports_ambiguous_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('everything')}
        supports_patient_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('patient-everything')}
        supports_encounter_everything = rest.operation.any?{|x|['$everything','everything'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('encounter-everything')}

        message = 'Excerpt from patient-operations.html#everything and encounter-operations.html#everything: In the US Realm, at a minimum, the resources returned SHALL include all the data covered by the meaningful use common data elements as defined in DAF/USCore.'

        assert((supports_patient_everything || supports_encounter_everything || supports_ambiguous_everything), message)
        warning{ assert((supports_patient_everything || supports_encounter_everything), "Ambiguous everything operation: cannot determine applicable resources. #{message}") }
        warning{ assert(supports_patient_everything, "Cannot find Patient $everything operation. #{message}")}
        warning{ assert(supports_encounter_everything, "Cannot find Encounter $everything operation. #{message}")}
      end

      # Check CapabilityStatement for $validate operation support
      # NOT REQUIRED BY USCore IMPLEMENTATION GUIDE -- WARNING ONLY
      test 'US05','Optional: Check CapabilityStatement for $validate Operation Support' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        assert(@conformance, 'No capability statement found.')
        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        @supports_validate = rest.operation.any?{|x|['$validate','validate'].include?(x.name.downcase) && x.definition.reference.downcase.ends_with?('validate')}
        message = 'Although not required by the USCore Implementation Guide, the server should support resource validation to ensure resources correctly conform to the USCore profiles.'
        warning{ assert(@supports_validate, message) }
      end

      # Check CapabilityStatement for transaction support
      # NOT REQUIRED BY USCORE IMPLEMENTATION GUIDE -- WARNING ONLY
      test 'US06','Optional: Check CapabilityStatement for Transaction Support' do
        metadata {
          links "#{REST_SPEC_LINK}#conformance"
          links "#{BASE_SPEC_LINK}/conformance.html"
          links "#{REST_SPEC_LINK}#capabilitystatement"
          links "#{BASE_SPEC_LINK}/capabilitystatement.html"
          links "#{BASE_SPEC_LINK}/us/core/"
          links "#{REST_SPEC_LINK}#transaction"
          requires resource: 'Conformance', methods: ['read']
          requires resource: 'CapabilityStatement', methods: ['read']
          validates resource: 'Conformance', methods: ['read']
          validates resource: 'CapabilityStatement', methods: ['read']
        }

        assert(@conformance, 'No capability statement found.')
        rest = @conformance.rest.first
        rest = @conformance.rest[@rest_index] if @found_smart_code

        has_transaction_interaction = rest.interaction.any?{|x|x.code=='transaction'}
        has_transaction_mode = (!rest.interaction.try(:first).nil? && rest.interaction.first.code != 'not-supported')

        message = 'Although not required by the USCore Implementation Guide, the server should support transaction (preferred) or batch, to facilitate the transfer of patient records.'

        warning{ assert((has_transaction_interaction || has_transaction_mode), message) }
      end

      # Validate invalid USCore patient
      test 'US07', 'Optional: Server should not $validate an invalid USCore-Patient' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/us/core/StructureDefinition-us-core-patient.html"
          links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
          links "#{BASE_SPEC_LINK}/operation-resource-validate.html"
          requires resource: 'Patient', methods: ['$validate']
          validates profiles: ['validate-profile']
        }
        skip 'Validate not supported.' unless @supports_validate

        # Removing the identifier and adding an "animal" to the
        # Patient violates the USCore-Patient profile.
        patient = Crucible::Tests::USCoreResourceGenerator.patient
        patient.identifier = nil
        patient.animal = Crucible::Tests::USCoreResourceGenerator.minimal_animal
        reply = @client.validate(patient,{profile_uri: patient.meta.profile.first})
        assert_response_ok(reply)
        reply_resource = @client.parse_reply(FHIR::OperationOutcome, @client.default_format, reply)
        reply.resource = reply_resource
        assert_resource_type(reply,FHIR::OperationOutcome)
        failed = reply.resource.issue.any?{|x|['fatal','error'].include?(x.severity) || x.code=='invalid' }
        assert(failed,'The server failed to reject an invalid USCore-Patient.')
      end

      # Create Invalid USCore Profile fixtures, server should reject
      # Validate valid and invalid USCore fixtures (server should PASS and FAIL appropriately)
      # Search for USCore Profile fixtures (including by using USCore extensions)

      # Test $everything on Patient and Encounter
      test 'US08','Test $everything on Patient' do
        metadata {
          links "#{BASE_SPEC_LINK}/us/core/"
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
        skip 'Patient resource not created.' if resource.nil? || resource.empty?

        reply = @client.fetch_patient_record(resource.first.id)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test 'US09','Test $everything on Encounter' do
        metadata {
          links "#{BASE_SPEC_LINK}/us/core/"
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
        skip 'Encounter resource not created.' if resource.nil? || resource.empty?

        reply = @client.fetch_encounter_record(resource.first.id)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      # Create USCore Profile fixtures
      # => all MUST SUPPORT fields
      # => using USCore bindings
      # => with all USCore EXTENSIONS
      # BUT THE USCore IMPLEMENTATION GUIDE DOES NOT REQUIRE CREATE/WRITE SUPPORT.
      # TRY TO VALIDATE THESE FIXTURES... BUT VALIDATE OPERATION IS NOT REQUIRED BY USCore IG EITHER.
      # TRY TO SEARCH FOR USCore PROFILED RESOURCES... AND THEN HAVE OUR CLIENT VALIDATE THEM, IF THEY EXIST.
      resources = Crucible::Generator::Resources.new
      uscore_conformance = resources.uscore_conformance
      uscore_conformance.rest.first.resource.each_with_index do |uscore_resource,index|

        key = ((index+1)*10)

        test "US#{key+1}_#{uscore_resource.type}", "Search #{uscore_resource.type} for USCore-#{uscore_resource.type} compliant resources" do
          metadata {
            links "#{BASE_SPEC_LINK}/resource.html#profile-tags"
            links "#{BASE_SPEC_LINK}/us/core/StructureDefinition-us-core-#{uscore_resource.type.downcase}.html"
            links "#{REST_SPEC_LINK}#search"
            requires resource: "#{uscore_resource.type}", methods: ['search']
            validates resource: "#{uscore_resource.type}", methods: ['search']
          }

          klass = "FHIR::#{uscore_resource.type}".constantize
          options = {
            :search => {
              :parameters => {
                '_profile' => uscore_conformance.profile.detect{|p| p.extension.first.valueCode == uscore_resource.type }.reference
              }
            }
          }
          # search on the resource by ?_profile=
          reply = @client.search(klass,options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          warning{ assert((1 >= reply.resource.entry.size), "The server did not return any USCore-#{uscore_resource.type}s.") }

          if reply.resource.entry.size > 0
            # store any results to a @server_side_resources
            @server_side_resources[uscore_resource.type] = reply.resource.entry.map{|x|x.resource}
          end
        end

        # if there are any profiled results in the @variable, and the server supports $validate, then $validate them
        test "US#{key+3}_#{uscore_resource.type}", "Server-side validation of USCore-#{uscore_resource.type} search results" do
          metadata {
            links "#{BASE_SPEC_LINK}/resource-operations.html#validate"
            links "#{BASE_SPEC_LINK}/us/core/StructureDefinition-us-core-#{uscore_resource.type.downcase}.html"
            validates resource: "#{uscore_resource.type}", methods: ['$validate']
            validates profiles: ['validate-profile']
          }
          skip 'Validate not supported.' unless @supports_validate
          resource = @server_side_resources[uscore_resource.type]
          skip "#{uscore_resource.type} not created properly." if resource.nil? || resource.empty?

          resource.each do |r|
            reply = @client.validate(r,{profile_uri: uscore_conformance.profile.detect{|p| p.extension.first.valueCode == uscore_resource.type }.reference})
            assert_response_ok(reply)
            if !reply.id.nil?
              assert( !reply.id.include?('validate'), "Server created an #{uscore_resource.type} with the ID `#{reply.resource.id}` rather than validate the resource.", reply.id)
            end
          end
        end
      end
    end
  end
end
