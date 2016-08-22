module Crucible
  module Tests
    class SyncForScienceTest < BaseSuite
      attr_accessor :rc

      def id
        'SyncForScienceTest'
      end

      def description
        'S4S is a collaboration among researchers, electronic health record vendors, and the United States federal government. This suite is designed to test the Sync for Science authorization methods and API calls.'
      end

      def details
        {
          'Overview' => 'S4S is a collaboration among researchers (Harvard Medical School Department of Biomedical Informatics), electronic health record vendors (Allscripts, athenahealth, Cerner, drchrono, eClinicalWorks, Epic, McKesson), and the United States federal government (Office of the National Coordinator for Health IT, Office of Science and Technology Policy, and National Institutes of Health).',
          'FHIR API Calls' => 'For information about the API calls used in S4S, see http://syncfor.science/api-calls/',
          'Authorization' => 'S4S uses a minimum subset of the SMART on FHIR authorization protocol, consisting of confidential clients, the standalone launch flow, and the patient/*.read, launch/patient, and offline_access scopes.'
        }
      end

      def initialize(client1, client2 = nil)
        super
        @tags.append('s4s')
        @category = {id: 's4s', title: 'Sync For Science'}
      end

      test 'S4S01', 'GET FHIR Server metadata' do
        metadata {
          links "#{BASE_SPEC_LINK}/resource.html#metadata"
          links 'http://syncfor.science/api-calls/#authorization-expectations'
          requires resource: "Conformance", methods: ["read"]
          validates resource: "Conformance", methods: ["read"]
        }

        conformance = @client.conformanceStatement
        options = get_security_options(conformance)
        assert options[:authorize_url], "Authorize URL was not found in the conformance"
        assert options[:token_url], "Token URL was not found in the conformance"
      end

      test 'S4S02', 'GET Patient Demographics' do
        metadata {
          links "#{BASE_SPEC_LINK}#read"
          links 'http://syncfor.science/api-calls/#patient-demographics-mu-ccds-1-6httpswwwhealthitgovsitesdefaultfiles2015edccgccdspdf'
          requires resource: 'Patient', methods: ['read']
          validates resource: 'Patient', methods: ['read']
        }

        assert !@client.client.try(:params).nil?, "The client was not authorized for the test"
        assert @client.client.params["patient"], "No patient parameter was passed to the client"

        patient_id = @client.client.params["patient"]

        reply = @client.read(FHIR::Patient, patient_id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }

        patient = reply.resource

        patient.name.each do |name|
          assert !name.family.empty?, "Patient #{patient.xmlId} has a name with an empty 'family' value"
          assert !name.given.empty?, "Patient #{patient.xmlId} has a name with an empty 'given' value"
        end
        assert %w{male female other unknown}.include?(patient.gender), "Patient #{patient.xmlId} does not have a gender from the AdministrativeGender Value Set"
        patient.identifier.each do |id|
          assert !id.system.empty?, "Patient #{patient.xmlId} identifier does not have a 'system'"
          assert !id.value.empty?, "Patient #{patient.xmlId} identifier does not have a 'value'"
        end
        assert !patient.birthDate.empty?, "Patient #{patient.xmlId} must have a birthdate"
        # TODO add extensions
      end

      test 'S4S03', 'GET Patient Smoking Status' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links 'http://syncfor.science/api-calls/#smoking-status-mu-ccds-7httpswwwhealthitgovsitesdefaultfiles2015edccgccdspdf'
          requires resource: 'Observation', methods: ['read', 'search']
          validates resource: 'Observation', methods: ['read', 'search']
        }

        
      end

      private

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
                    options[:authorize_url] = ext.value
                  when "#{oauth_extension}\##{authorize_extension}"
                    options[:authorize_url] = ext.value
                  when token_extension
                    options[:token_url] = ext.value
                  when "#{oauth_extension}\##{token_extension}"
                    options[:token_url] = ext.value
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
