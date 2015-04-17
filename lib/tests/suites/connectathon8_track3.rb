module Crucible
  module Tests
    class TrackThreeTest < BaseSuite

      def id
        'Connectathon8Track3'
      end

      def description
        'Connectathon 8 Track 3 Tests'
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        @profile = @resources.track3_profile
        @profile.xmlId = nil
        @profile.identifier = nil # clear the identifiers, in case the server checks for duplicates
        reply = @client.create @profile
        @profile.xmlId = reply.id if !reply.id.nil?

        options = {
          id: @profile.xmlId,
          resource: @profile.class,
          format: nil
        }
        @profile_url = @client.full_resource_url(options)
        @profile_url = reply.self_link if !reply.self_link.nil?

        @obs = @resources.track3_observations
        @obs.each do |x|
          x.xmlId = nil
          x.identifier = nil # clear the identifiers, in case the server checks for duplicates
          x.meta = nil
        end
      end

      def teardown
        @client.destroy(FHIR::Profile, @profile.xmlId) if !@profile.xmlId.nil?
        # @obs.each do |x|
        #   @client.destroy(FHIR::Observation, x.xmlId) if !x.xmlId.nil?
        # end
      end

      #
      # Test if we can validate observations against the general specification.
      #
      test 'C8T3_2A','Validate Observations against the General Specification' do
        metadata {
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#Track_3_-_Experimental:_Profiles_and_conformance'
          links 'http://hl7.org/implement/standards/FHIR-Develop/profile.html'
          links 'http://hl7.org/implement/standards/FHIR-Develop/observation.html'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#validation'
          requires resource: 'Profile', methods: ['create']
          validates resource: 'Observation', methods: ['validate']
        }

        @obs.each do |x|
          reply = @client.validate(x)
          assert_response_ok(reply)
          if !reply.id.nil?
            assert( !reply.id.include?('_validate'), "Server created an Observation with the ID `_validate` rather than validate the resource.", reply.id)
          end
        end
      end

      #
      # Test if we can validate observations against a profile.
      #
      test 'C8T3_2B','Validate Observations against a Server-Side Profile' do
        metadata {
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#Track_3_-_Experimental:_Profiles_and_conformance'
          links 'http://hl7.org/implement/standards/FHIR-Develop/profile.html'
          links 'http://hl7.org/implement/standards/FHIR-Develop/observation.html'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#validation'
          requires resource: 'Profile', methods: ['create']
          validates resource: 'Observation', methods: ['validate']
        }

        @obs.each do |x|
          x.meta = FHIR::Resource::ResourceMetaComponent.new
          x.meta.profile = [ @profile_url ]
          reply = @client.validate(x)
          assert_response_ok(reply)
          if !reply.id.nil?
            assert( !reply.id.include?('_validate'), "Server created an Observation with the ID `_validate` rather than validate the resource.", reply.id)
          end
        end
      end

    end
  end
end
