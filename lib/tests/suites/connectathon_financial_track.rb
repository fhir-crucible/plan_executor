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
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @resources = Crucible::Generator::Resources.new(fhir_version)

        @simple = @resources.simple_claim
        @simple.id = nil # clear the identifier, in case the server checks for duplicates
        @simple.identifier = nil # clear the identifier, in case the server checks for duplicates

        @average = @resources.average_claim
        @average.id = nil # clear the identifier, in case the server checks for duplicates
        @average.identifier = nil # clear the identifier, in case the server checks for duplicates


        @preauth = @resources.complex_claim
        @preauth.id = nil # clear the identifier, in case the server checks for duplicates
        @preauth.identifier = nil # clear the identifier, in case the server checks for duplicates

        @er = @resources.eligibility_request
        @er.id = nil
        @er.identifier = nil

        @patient = @resources.minimal_patient
        @patient.id = nil
        @patient.identifier = [FHIR::Identifier.new]
        @patient.identifier[0].value = SecureRandom.urlsafe_base64
        result = @client.create(@patient)
        assert_response_ok(result)
        @patient_id = result.id

        @simple.careTeam = nil;
        @preauth.careTeam = nil;
        @average.careTeam = nil;

        @simple.patient.reference = "Patient/#{@patient_id}"
        @average.patient.reference = "Patient/#{@patient_id}"
        @preauth.patient.reference = "Patient/#{@patient_id}"
        @er.patient.reference = "Patient/#{@patient_id}"

        @organization_1 = @resources.example_patient_record_organization_201
        @organization_1.id = nil
        reply = @client.create @organization_1
        @organization_1_id = reply.id
        @organization_1.id = @organization_1_id
        assert_response_ok(reply)

        @simple.organization.reference = "Organization/#{@organization_1_id}"
        @average.organization.reference = "Organization/#{@organization_1_id}"
        @preauth.organization.reference = "Organization/#{@organization_1_id}"
        @er.organization.reference = "Organization/#{@organization_1_id}"

        @organization_2 = @resources.example_patient_record_organization_203
        @organization_2.id = nil
        reply = @client.create @organization_2
        @organization_2_id = reply.id
        @organization_2.id = @organization_2_id
        assert_response_ok(reply)

        @simple.insurer.reference = "Organization/#{@organization_2_id}"
        @average.insurer.reference = "Organization/#{@organization_2_id}"
        @preauth.insurer.reference = "Organization/#{@organization_2_id}"
        @er.insurer.reference = "Organization/#{@organization_2_id}"
      end

      def teardown
        @client.destroy(FHIR::Claim, @simple_id) if !@simple_id.nil?
        @client.destroy(FHIR::Claim, @preauth_id) if !@preauth_id.nil?
        @client.destroy(FHIR::Claim, @average_id) if !@average_id.nil?
        @client.destroy(FHIR::ClaimResponse, @simple_response_id) if !@simple_response_id.nil?
        @client.destroy(FHIR::ClaimResponse, @average_response_id) if !@average_response_id.nil?
        @client.destroy(FHIR::ClaimResponse, @preauth_response_id) if !@preauth_response_id.nil?
        @client.destroy(FHIR::Patient, @patient_id) if !@patient_id.nil?
        @client.destroy(FHIR::Organization, @organization_1_id) if !@organization_1_id.nil?
        @client.destroy(FHIR::Organization, @organization_2_id) if !@organization_2_id.nil?
        @client.destroy(FHIR::EligibilityRequest, @er_id) if !@er_id.nil?
        @client.destroy(FHIR::Communication, @preauth_communication_id) if !@preauth_communication_id.nil?
      end

      test 'C13F_1', 'Register an EligibilityRequest' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/eligibilityrequest.html"
          links 'http://wiki.hl7.org/index.php?title=201609_Financial_Management#Submit_an_Eligibility.2C_Retrieve.2FReceive_an_EligibilityResponse'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          validates resource: 'EligibilityRequest', methods: ['create']
        }

        reply = @client.create(@er)

        assert_response_ok(reply)
        @er_id = reply.id

        warning { assert @er.equals?(reply.resource), 'The server did not correctly preserve the EligibilityRequest data.' }

      end

      test 'C13F_2', 'Search for EligibilityResponse' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/eligibilityresponse.html"
          links 'http://wiki.hl7.org/index.php?title=201609_Financial_Management#Submit_an_Eligibility.2C_Retrieve.2FReceive_an_EligibilityResponse'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'EligibilityRequest', methods: ['search']
          validates resource: 'EligibilityRequest', methods: ['search']
        }

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'identifier' => @er_id
            }
          }
        }

        sleep(5)

        # @client.use_format_param = true
        reply = @client.search(FHIR::EligibilityResponse, options)

        assert_response_ok(reply)
        assert (reply.resource.total > 0), 'The server did not report any EligibilityResponses for the submitted EligibilityResource.'
      end

      test 'C13F_3', 'Submit a PreAuthorization and an Attachment' do

        # Action: The FHIR Client will construct a Claim resource indicating Pre-Authorization. The service will respond with a
        # ClaimResponse indicating only receipt not adjudication of the Claim (Pre-Authorization).
        # To obtain the adjudicated ClaimResponse the client must then submit an Attachment (Communication resource) containing any
        # supporting material to which the Server will respond with a ProcessResponse indicating success or failure with errors.
        # Then the client may obtain the adjudicated ClaimResponse via the appropriate protocol. The ClaimResponse will contain
        # an identifier which may be used during claim submission to indicate that the Pre-Authorization has been performed.
        # Precondition: None
        # Success Criteria: Pre-Authorization and Attachment processed correctly by the Server (inspect via browser or available UI)
        # Bonus point: For sending a business-appropriate form of attachment.

        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=201609_Financial_Management'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'Claim', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'Claim', methods: ['create']
          validates resource: 'ClaimResponse', methods: ['search']
        }

        reply = @client.create(@preauth)
        assert_response_ok(reply)
        @preauth_id = reply.id
        sleep(10) # sleep to allow server to process claim, no wait time was causing incorrect failures in subsequent tests

        if !reply.resource.nil? && reply.resource.resourceType == "Claim"
          # Response is Claim
          temp = reply.resource.id
          reply.resource.id = nil
          warning { assert @simple.equals?(reply.resource), 'The server did not correctly preserve the Claim data.' }
          reply.resource.id = temp
        elsif !reply.body.nil?
          begin
            @preauth_response = FHIR.from_contents(reply.body)
            if cr.class==FHIR::ClaimResponse
              # Response is ClaimResponse
              @preauth_response_id = @preauth_response.id
            else
              warning { assert(false,"The Claim request responded with an unexpected resource: #{cr.class}",reply.body) }
              @preauth_response = nil
            end
          rescue Exception => ex
            @preauth_response = nil
            warning { assert(false,'The Claim request responded with an unexpected body.',reply.body) }
          end
        end

        # get the claim response if we weren't given one back directly

        search_string = @preauth_id
        search_regex = Regexp.new(search_string)

        if @preauth_response.nil?
          options = {
            :search => {
              :flag => true,
              :compartment => nil,
              :parameters => {
                'request' => search_string
              }
            }
          }
          @client.use_format_param = true
          reply = @client.search(FHIR::ClaimResponse, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          assert (reply.resource.total > 0), 'The server does not have a record of the submitted preauthorization.'
          assert(reply.resource.entry[0].resource.request.reference.include?(@preauth_id), 'The server did not return a request with the proper preauthorization.')

          @preauth_response = reply.resource.entry[0].resource
          @preauth_response_id = @preauth_response.id
        end

        # check receipt and not adjudication of the claim
        # To do this, we will just make sure that it isn't marked as "complete"
        # This may not be the proper method

        assert_operator(:notEquals, @preauth_response.outcome, 'complete', 'The current status of the preauth should not be complete')

        # create an communication that references additional information for the claim

        @preauth_communication = FHIR::Communication.new()
        # Associate with the claim using the topic
        # This might not be the appopriate place to do this
        @preauth_communication.topic = [ FHIR::Reference.new ]
        @preauth_communication.topic[0].reference = "Claim/#{@preauth_id}"

        attachment = FHIR::Attachment.new
        attachment.data = File.read(File.join(Crucible::Generator::Resources::FIXTURE_DIR, 'attachment', 'ccda_pdf_base64.txt'))
        # attachment.data = 'SGVsbG8='
        attachment.contentType = 'application/pdf'

        payload = FHIR::Communication::Payload.new
        payload.contentAttachment = attachment

        @preauth_communication.payload = [payload]

        reply = @client.create(@preauth_communication)
        assert_response_ok(reply)
        @preauth_communication_id = reply.id


        #TODO: The Server will respond with a ProcessResponse indicating success or failure with errors.
        #Then the client may obtain the adjudicated ClaimResponse via the appropriate protocol.
        #The ClaimResponse will contain an identifier which may be used during claim submission to indicate
        #that the Pre-Authorization has been performed.

      end

      #
      # Test if we can create a new Claim.
      #
      test 'C9F_1A','Register a simple claim' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/claim.html"
          links 'http://wiki.hl7.org/index.php?title=Connectathon9_Financial#Submit_a_Claim_via_REST.2C_Retrieve_a_ClaimResponse'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'Claim', methods: ['read']
          validates resource: 'Claim', methods: ['read']
        }

        reply = @client.read(FHIR::Claim,@simple_id)
        assert_response_ok(reply)
        assert_resource_type(reply,FHIR::Claim)
        reply.resource.insurance.each do |insurance|
          assert(!insurance.try(:claimResponse).try(:reference).nil?,'Claim does not reference a ClaimResponse.',reply.body)
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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'Claim', methods: ['read']
          validates resource: 'Claim', methods: ['read']
        }

        reply = @client.read(FHIR::Claim,@average_id)
        assert_response_ok(reply)
        assert_resource_type(reply,FHIR::Claim)
        reply.resource.insurance.each do |insurance|
          assert(!insurance.try(:claimResponse).try(:reference).nil?,'Claim does not reference a ClaimResponse.',reply.body)
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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Simple claim not successfully registered in C9F_1A.' unless @simple_id

        search_string = @simple_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'request' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'
        assert(reply.resource.entry[0].resource.request.reference.include?(@simple_id), 'The server did not return a request with the proper claim')

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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Simple claim not successfully registered in C9F_1A.' unless @simple_id

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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Simple claim not successfully registered in C9F_1A.' unless @simple_id

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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Average claim not successfully registered in C9F_1B.' unless @average_id

        search_string = @average_id
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'request' => search_string
            }
          }
        }
        @client.use_format_param = true
        reply = @client.search(FHIR::ClaimResponse, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'

        assert(reply.resource.entry[0].resource.request.reference.include?(@average_id), 'The server did not return a request with the proper claim')
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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Average claim not successfully registered in C9F_1B.' unless @average_id

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
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Organization', methods: ['create']
          requires resource: 'ClaimResponse', methods: ['search']
          validates resource: 'ClaimResponse', methods: ['search']
        }
        skip 'Average claim not successfully registered in C9F_1B.' unless @average_id

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
