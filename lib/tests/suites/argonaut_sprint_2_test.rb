module Crucible
  module Tests
    class ArgonautSprint2Test < BaseSuite
      attr_accessor :rc
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader   :canSearchById

      def id
        'ArgonautSprint2Test'
      end

      def description
        'Argonaut Sprint 2 tests for testing Argonauts Sprint 2 goals: builds on sprint 1 and provides authorization.'
      end

      def details
        {
          'Overview' => 'Argonaut Implementation Sprint 2 focuses on a scenario where an end-user launches an app from outside of the EHR, and the app gets access to search demographics for a population of patients. That is, the app obtains "user-level" authorization to search whatever patients the end-user is allowed to see.',
          'Instructions' => 'This sprint builds directly on Sprint 1, adding a FHIR conformance statement and a basic OAuth 2 implementation for authorization.',
          'FHIR API Calls' => 'Sprint 2 builds on the demographics call from Sprint 1: GET /Patient?[parameters] See Sprint 1 for details. We also add support for a server-specific FHIR Conformance statement, which is a necessary component for endpoint discovery in the authorization protocol. The API call looks like: GET /metadata or (equivalently) OPTIONS / Obtain the FHIR conformance statement for this RESTful server. Each server\'s metadata must include SMART\'s endpoint discovery extensions to enable the OAuth 2.0 process described below.',
          'Authorization' => 'This sprint introduces the SMART on FHIR OAuth 2.0 authorization process. SMART\'s authorization specs define a number of advanced features, including the ability to pass context from the EHR to a contained app, and to authorize access to a single patient record at a time — but for this sprint, we support only the most basic functionality: delegating a user\'s rights to an app.',
        }
      end

      def requires_authorization
        false
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('argonaut')
        @category = {id: 'argonaut', title: 'Argonaut'}
      end

      def setup
      end

      test 'AS2001', 'Test conformance statement contains an authorize url' do
        metadata {
          links "#{BASE_SPEC_LINK}/resource.html#metadata"
          requires resource: "Conformance", methods: ["read"]
          validates resource: "Conformance", methods: ["read"]
          validates resource: nil, methods: ['OAuth2', 'Authorization/Access Control']
          requires resource: nil, methods: ['OAuth2', 'Authorization/Access Control']
        }

        conformance = @client.conformanceStatement
        options = get_security_options(conformance)

        assert options[:authorize_url], "Authorize Url was not found in the conformance"

      end


      test 'AS2002', 'Test conformance statement contains a token url' do
        metadata {
          links "#{BASE_SPEC_LINK}/resource.html#metadata"
          requires resource: "Conformance", methods: ["read"]
          validates resource: "Conformance", methods: ["read"]
          validates resource: nil, methods: ['OAuth2', 'Authorization/Access Control']
          requires resource: nil, methods: ['OAuth2', 'Authorization/Access Control']
        }

        conformance = @client.conformanceStatement
        options = get_security_options(conformance)

        assert options[:token_url], "Token Url was not found in the conformance"

      end

      def get_security_options(conformance)
        oauth_extension = 'http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris'
        authorize_extension = 'authorize'
        token_extension = 'token'

        options = nil
        conformance.rest.each do |rest|
          assert !rest.security.nil?, "could not get authorization extensions, no security section"
          assert !rest.security.service.nil?, "could not get authorization extensions, no security/service section"
          rest.security.service.each do |service|
            assert !service.coding.nil?, "could not get authorization extensions, no codings on sercurity/service"
            found_oauth2_code = false
            service.coding.each do |coding|
              if coding.code == 'SMART-on-FHIR'
                found_oauth2_code = true
                assert !rest.security.extension.nil?, "could not get authorization extensions, no security extensions"
                found_oauth_extension = false
                options = {}
                rest.security.extension.where({url: oauth_extension}).first.extension.each do |ext|
                  found_oauth_extension = true
                  case ext.url
                  when authorize_extension
                    options[:authorize_url] = ext.value.value
                  when "#{oauth_extension}\##{authorize_extension}"
                    options[:authorize_url] = ext.value.value
                  when token_extension
                    options[:token_url] = ext.value.value
                  when "#{oauth_extension}\##{token_extension}"
                    options[:token_url] = ext.value.value
                  end
                end
                assert found_oauth_extension, "an OAuth extension could not be found"
              end
              assert found_oauth2_code, "a security coding set to SMART-on-FHIR could not be found"
            end
          end
        end
        assert !options.nil?, "could not get authorization extensions"
        options
      end

    end
  end
end
