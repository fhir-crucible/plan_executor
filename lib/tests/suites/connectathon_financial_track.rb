module Crucible
  module Tests
    class ConnectathonFinancialTrackTest < BaseSuite

      def id
        'ConnectathonFinancialTrackTest'
      end

      def description
        'Connectathon Financial Track Test focuses on submitting Claims and retreiving ClaimResponses.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        @simple = @resources.simple_claim
        @simple.id = nil # clear the identifier, in case the server checks for duplicates
        @simple.identifier = nil # clear the identifier, in case the server checks for duplicates

        @average = @resources.average_claim
        @average.id = nil # clear the identifier, in case the server checks for duplicates
        @average.identifier = nil # clear the identifier, in case the server checks for duplicates
      end

      def teardown
        @client.destroy(FHIR::Claim, @simple_id) if !@simple_id.nil?
        @client.destroy(FHIR::ClaimResponse, @simple_response_id) if !@simple_response_id.nil?
        @client.destroy(FHIR::Claim, @average_id) if !@average_id.nil?
        @client.destroy(FHIR::ClaimResponse, @average_response_id) if !@average_response_id.nil?
      end

      #
      # Test if we can create a new Claim.
      #
      test 'C9F_1A','Register a simple claim' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'Claim', methods: ['create']
          validates resource: 'Claim', methods: ['create']
        }

        reply = @client.create(@simple)
        assert_response_ok(reply)
        @simple_id = reply.id
        sleep(10) # sleep to allow server to process claim, no wait time was causing incorrect failures in subsequent tests

        if !reply.resource.nil?
          # Response is Claim
          temp = reply.resource.id
          reply.resource.id = nil
          warning { assert @simple.equals?(reply.resource), 'The server did not correctly preserve the Claim data.' }
          reply.resource.id = temp
        elsif !reply.body.nil?
          begin
            cr = FHIR.from_contents(reply.body)
            if cr.class==FHIR::ClaimResponse
              # Response is ClaimResponse
              @simple_response_id = cr.id
              @simple_id = cr.request.reference if cr.request
            else
              warning { assert(false,"The Claim request responded with an unexpected resource: #{cr.class}",reply.body) }
            end
          rescue Exception => ex
            warning { assert(false,'The Claim request responded with an unexpected body.',reply.body) }
          end
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can create a different new Claim.
      #
      test 'C9F_1B','Register an average claim' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'Claim', methods: ['create']
          validates resource: 'Claim', methods: ['create']
        }

        reply = @client.create(@average)
        assert_response_ok(reply)
        @average_id = reply.id
        sleep(10) # sleep to allow server to process claim, no wait time was causing incorrect failures in subsequent tests

        if !reply.resource.nil?
          # Response is Claim
          temp = reply.resource.id
          reply.resource.id = nil
          warning { assert @average.equals?(reply.resource), 'The server did not correctly preserve the Claim data.' }
          reply.resource.id = temp
        elsif !reply.body.nil?
          begin
            cr = FHIR.from_contents(reply.body)
            if cr.class==FHIR::ClaimResponse
              # Response is ClaimResponse
              @average_response_id = cr.id
              @average_id = cr.request.reference if cr.request
            else
              warning { assert(false,"The Claim request responded with an unexpected resource: #{cr.class}",reply.body) }
            end
          rescue Exception => ex
            warning { assert(false,'The Claim request responded with an unexpected body.',reply.body) }
          end
        end
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      # ------------------------------------------------------------------------------

      #
      # Check if our claim now has a reference to a ClaimResponse
      #
      test 'C9F_1C','Check on simple claim' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'Claim', methods: ['read']
          validates resource: 'Claim', methods: ['read']
        }

        reply = @client.read(FHIR::Claim,@simple_id)
        assert_response_ok(reply)
        assert_resource_type(reply,FHIR::Claim)
        reply.resource.coverage.each do |coverage|
          assert(!coverage.try(:claimResponse).try(:reference).nil?,'Claim does not reference a ClaimResponse.',reply.body)
        end
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Check if our claim now has a reference to a ClaimResponse
      #
      test 'C9F_1D','Check on average claim' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'Claim', methods: ['read']
          validates resource: 'Claim', methods: ['read']
        }

        reply = @client.read(FHIR::Claim,@average_id)
        assert_response_ok(reply)
        assert_resource_type(reply,FHIR::Claim)
        reply.resource.coverage.each do |coverage|
          assert(!coverage.try(:claimResponse).try(:reference).nil?,'Claim does not reference a ClaimResponse.',reply.body)
        end
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      # ------------------------------------------------------------------------------

      #
      # Search for a ClaimResponse by simple claim
      #
      test 'C9F_2A_request', 'Search ClaimResponse by simple claim ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @simple_id

        search_string = @simple_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'requestreference' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert(reply.resource.entry[0].resource.requestReference.reference.include?(@simple_id), 'The server did not return a request with the proper claim')
        assert (reply.resource.total > 0), 'The server did not report any results.'

        @simple_response_id = reply.resource.entry[0].resource.id unless @simple_response_id
      end

      #
      # Search for a ClaimResponse by simple claim
      #
      test 'C9F_2A_text', 'Search ClaimResponse by simple claim ID in the text' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @simple_id

        search_string = @simple_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_text' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        @simple_response_id = reply.resource.entry[0].resource.id unless @simple_response_id
      end

      #
      # Search for a ClaimResponse by simple claim
      #
      test 'C9F_2A_content', 'Search ClaimResponse by simple claim ID in the content' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @simple_id

        search_string = @simple_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_content' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        @simple_response_id = reply.resource.entry[0].resource.id unless @simple_response_id
      end

      # ------------------------------------------------------------------------------

      #
      # Search for a ClaimResponse by average claim
      #
      test 'C9F_2B_request', 'Search ClaimResponse by average claim ID' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @average_id

        search_string = @average_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'requestreference' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        assert(reply.resource.entry[0].resource.requestReference.reference.include?(@average_id), 'The server did not return a request with the proper claim')
        @average_response_id = reply.resource.entry[0].resource.id unless @average_response_id
      end

      #
      # Search for a ClaimResponse by average claim
      #
      test 'C9F_2B_text', 'Search ClaimResponse by average claim ID in the text' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @average_id

        search_string = @average_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_text' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        @average_response_id = reply.resource.entry[0].resource.id unless @average_response_id
      end

      #
      # Search for a ClaimResponse by average claim
      #
      test 'C9F_2B_content', 'Search ClaimResponse by average claim ID in the content' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/claimresponse.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip unless @average_id

        search_string = @average_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_content' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        @average_response_id = reply.resource.entry[0].resource.id unless @average_response_id
      end

    end
  end
end
