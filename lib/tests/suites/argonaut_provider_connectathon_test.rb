module Crucible
  module Tests
    class ArgonautProviderConnectathonTest < BaseSuite
      def id
        'ArgonautProviderConnectathonTest'
      end

      def description
        'Test suite for the Argonaut Provider Directory Virtual Connectathon'
      end

      def details
        {
          'Overview' => 'Test suite for the Argonaut Provider Directory Virtual Connectathon'
        }
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
        @tags.append('provider')
        @category = {id: 'argonaut', title: 'Argonaut'}
      end

      test 'APCT01', 'GET A set of practitioners to test' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'Practitioner', methods: ['read', 'search']
          validates resource: 'Practitioner', methods: ['read', 'search']
        }

        # Basically just get a group of 10 Practitioners
        options = {
            :search => {
              :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 100
              }
            }
          }
          @practitioners = @client.search(FHIR::Practitioner, options).resource.try(:entry)
          assert @practitioners, 'No Practitioners found'
          @practitioner_id = @practitioners.select{ |p| !p.resource.practitionerRole.empty? }.sample.try(:resource).try(:id)
          assert @practitioner_id, 'No practitioner found with a PractitionerRole'
      end

      test 'APCT02', 'Test Ability to locate a Practitioner\'s Telecom/Physical Address' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Practitioner', methods: ['read']
          validates resource: 'Practitioner', methods: ['read']
        }

        skip if !@practitioner_id

        @practitioner = @client.read(FHIR::Practitioner, @practitioner_id).try(:resource)

        assert @practitioner, "No Practitioner found for ID #{@practitioner_id}"

        assert @practitioner.practitionerRole.select{ |pr| !pr.location.empty? }.size >= 1, "No Locations found for Practitioner #{@practitioner.identifier}"

        assert @practitioner.practitionerRole.select{ |pr| !pr.location.select {|loc| loc.address != nil }.empty? }.size >= 1, "No addresses found for Practitioner #{@practitioner.identifier.value}"

        assert @practitioner.practitionerRole.select{ |pr| !pr.telecom.empty? }.size >= 1, "No telecoms found for Practitioner #{@practitioner.identifier.value}"

      end
    end
  end
end
