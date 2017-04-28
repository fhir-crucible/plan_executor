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
        @tags.append('connectathon')
        @category = {id: 'argonaut', title: 'Argonaut'}
      end

      test 'APCT01', 'GET a set of Practitioners to test' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#search"
          requires resource: 'Practitioner', methods: ['read', 'search']
          validates resource: 'Practitioner', methods: ['read', 'search']
        }

        # Basically just get a group of 10 Practitioners
        options = {
            :search => {
              # :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 100
              }
            }
          }

          result = @client.search(FHIR::Practitioner, options)

          assert_response_ok(result)

          @practitioners = result.resource.try(:entry)

          assert @practitioners, 'No Practitioners found'

      end

      test 'APCT02', 'Test ability to locate a Practitioner\'s Telecom/Physical Address' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Practitioner', methods: ['read']
          validates resource: 'Practitioner', methods: ['read']
        }

        skip if !@practitioners

        practitioner_id = @practitioners.select{ |p| !p.resource.telecom.empty? || !p.resource.address.empty? }.sample.try(:resource).try(:id)
        assert practitioner_id, 'No practitioner found with a telecom or address'
      end

      test 'APCT03', 'Test ability to locate a Provider\'s Email Address' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Practitioner', methods: ['read', 'search']
          requires resource: 'PractitionerRole', methods: ['read']
          requires resource: 'Location', methods: ['read']
          validates resource: 'Practitioner', methods: ['read', 'search']
          validates resource: 'PractitionerRole', methods: ['read']
          validates resource: 'Location', methods: ['read']
        }
        skip if !@practitioners

        assert @practitioners.select { |p| p.resource.telecom.detect{|t| t.system=='email'} }.size >= 1, "No practitioner found with an email address"
      end

      test 'APCT04', 'Test ability to locate an Organization\'s Endpoint' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Organization', methods: ['read', 'search']
          requires resource: 'Endpoint', methods: ['read']
          validates resource: 'Organization', methods: ['read', 'search']
          validates resource: 'Endpoint', methods: ['read']
        }

        options = {
            :search => {
              # :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 100
              }
            }
          }

        result = @client.search(FHIR::Organization, options)

        assert_response_ok(result)

        orgs = result.resource.try(:entry)

        assert orgs, 'No Organizations found'

        assert orgs.select{ |org| !org.resource.endpoint.empty? }.size >= 1, "No Organization found with an Endpoint"
      end

      test 'APCT05', 'Test ability to locate a Location\'s Telecom/physical address' do
        metadata {
          requires resource: 'Location', methods: ['read']
          validates resource: 'Location', methods: ['read']
        }

        options = {
            :search => {
              # :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 100
              }
            }
          }

        result = @client.search(FHIR::Location, options)

        assert_response_ok(result)

        locs = result.resource.try(:entry)

        assert locs, "No Locations found"

        assert locs.select { |loc| !loc.resource.address.nil? }.size >= 1, "No Locations found with non-empty Address"

        assert locs.select { |loc| !loc.resource.telecom.nil? && !loc.resource.telecom.empty? }.size >= 1, "No Locations found with non-empty Telecom"

      end

      test 'APCT06', 'Test ability to locate a Location\'s Endpoint' do
        metadata {
          requires resource: 'Location', methods: ['read']
          validates resource: 'Location', methods: ['read']
          requires resource: 'Endpoint', methods: ['read']
          validates resource: 'Endpoint', methods: ['read']
        }

        options = {
            :search => {
              # :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 100
              }
            }
          }

        result = @client.search(FHIR::Location, options)

        assert_response_ok(result)

        locs = result.resource.try(:entry)

        assert locs, "No Locations found"

        assert locs.select { |loc| !loc.resource.endpoint.nil? && !loc.resource.endpoint.empty? }.size >= 1, "No Locations found with non-empty Endpoint"
      end

      private

      def resolve_reference(resource, reftype, id)
        return id if id.class == reftype || id.nil?
        loc = resource.contained.find { |con| con.id == id.gsub('#', '') }
        #if that doesn't work, try to read it from the server
        if loc.nil? || loc.try(:empty?)
          if id.split("/").count > 1
            res = @client.read(reftype, id.split("/")[1])

            assert_response_ok(res)
            loc = res.resource
          else
            res = @client.read(reftype, id)
            assert_response_ok(res)

            loc = res.resource
          end
        end
        assert !loc.nil?, "Could not find #{reftype.to_s.split("::")[1]} resource #{id}"

        loc
      end
    end
  end
end
