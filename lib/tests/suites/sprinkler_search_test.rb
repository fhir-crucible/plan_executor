module Crucible
  module Tests
    class SprinklerSearchTest < BaseSuite

      def id
        'Search001'
      end

      def description
        'Initial Sprinkler tests () for testing search capabilities.'
      end

      def setup
        # Create a patient with gender:missing
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient
        @patient.gender = nil
        result = @client.create(@patient)
        @patient_id = result.id

        # read all the patients
        @read_entire_feed=true
        @client.use_format_param = true
        reply = @client.read_feed(FHIR::Patient)
        @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        @total_count = 0
        @entries = []

        while reply != nil && !reply.resource.nil?
          @total_count += reply.resource.entry.size
          @entries += reply.resource.entry
          reply = @client.next_page(reply)
          @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        end

        # create a condition matching the first patient
        @condition = ResourceGenerator.generate(FHIR::Condition,1)
        @condition.patient.xmlId = @entries.try(:[],0).try(:resource).try(:xmlId)
        options = {
          :id => @entries.try(:[],0).try(:resource).try(:xmlId),
          :resource => @entries.try(:[],0).try(:resource).try(:class)
        }
        @condition.patient.reference = @client.resource_url(options)
        reply = @client.create(@condition)
        @condition_id = reply.id

        # create some observations
        @obs_a = create_observation(4.12345)
        @obs_b = create_observation(4.12346)
        @obs_c = create_observation(4.12349)
        @obs_d = create_observation(5.12)
        @obs_e = create_observation(6.12)
      end

      def create_observation(value)
        observation = FHIR::Observation.new
        observation.status = 'preliminary'
        observation.reliability = 'questionable'
        code = FHIR::Coding.new
        code.system = 'http://loinc.org'
        code.code = '2164-2'
        observation.code = FHIR::CodeableConcept.new
        observation.code.coding = [ code ]
        observation.valueQuantity = FHIR::Quantity.new
        observation.valueQuantity.system = 'http://unitofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.units = 'mmol'
        body = FHIR::Coding.new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySiteCodeableConcept = FHIR::CodeableConcept.new
        observation.bodySiteCodeableConcept.coding = [ body ]
        reply = @client.create(observation)
        reply.id
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient_id) if @patient_id
        @client.destroy(FHIR::Condition, @condition_id) if @condition_id
        @client.destroy(FHIR::Observation, @obs_a) if @obs_a
        @client.destroy(FHIR::Observation, @obs_b) if @obs_b
        @client.destroy(FHIR::Observation, @obs_c) if @obs_c
        @client.destroy(FHIR::Observation, @obs_d) if @obs_d
        @client.destroy(FHIR::Observation, @obs_e) if @obs_e
      end

      test 'SE01','Search patients without criteria (except _count)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          validates resource: "Patient", methods: ["search"]
        }
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_count' => '1'
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.entry.size, 'The server did not return the correct number of results.'
        warning { assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.' }
      end

      test 'SE02', 'Search on non-existing resource' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
        }
        options = {
          :resource => Crucible::Tests::SprinklerSearchTest,
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search_all(options)
        assert( (reply.code >= 400 && reply.code < 600), 'If the search fails, the return value should be status code 4xx or 5xx.', reply)
      end

      test 'SE03','Search patient resource on partial family surname' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#5.1.8"
          validates resource: "Patient", methods: ["search"]
        }
        skip unless @read_entire_feed
        search_string = @patient.name[0].family[0][0..2]
        search_regex = Regexp.new(search_string)
        # how many patients in the bundle have matching names?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          isMatch = false
          if !patient.nil? && !patient.name.nil?
            patient.name.each do |name|
              if !name.family.nil?
                name.family.each do |family|
                  if !(family =~ search_regex).nil?
                    isMatch = true
                  end
                end
              end
            end
          end
          expected += 1 if isMatch
        end

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'family' => search_string
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE04', 'Search patient resource on given name' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#5.1.8"
          validates resource: "Patient", methods: ["search"]
        }
        skip unless @read_entire_feed
        search_string = @patient.name[0].given[0]
        search_regex = Regexp.new(search_string)
        # how many patients in the bundle have matching names?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          isMatch = false
          if !patient.nil? && !patient.name.nil?
            patient.name.each do |name|
              if !name.given.nil?
                name.given.each do |given|
                  if !(given =~ search_regex).nil?
                    isMatch = true
                  end
                end
              end
            end
          end
          expected += 1 if isMatch
        end

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'given' => search_string
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.0', 'Search condition by patient reference url' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        options = {
          :id => @entries[0].resource.xmlId,
          :resource => @entries[0].resource.class
        }
        patient_url = @client.resource_url(options)

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient' => patient_url
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.1', 'Search condition by patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        patient_id = @entries[0].resource.xmlId

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient' => patient_id
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.2', 'Search condition by patient:Patient reference url' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        options = {
          :id => @entries[0].resource.xmlId,
          :resource => @entries[0].resource.class
        }
        patient_url = @client.resource_url(options)

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_url
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.3', 'Search condition by patient:Patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        patient_id = @entries[0].resource.xmlId

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_id
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.4', 'Search condition by patient:_id reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        patient_id = @entries[0].resource.xmlId

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient._id' => patient_id
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.5', 'Search condition by patient:name reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @read_entire_feed
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @entries[0].resource
        patient_name = patient.name[0].family[0]

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient.name' => patient_name
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE05.6', 'Search condition by patient:identifier reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @patient_id
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @patient
        patient_identifier = @patient.identifier[0].value

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'patient.identifier' => patient_identifier
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE06', 'Search condition by _include' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#4.3.4"
          validates resource: "Condition", methods: ["search"]
        }
        skip unless @patient_id
        # pick some search parameters... we previously created
        # a condition for the first (0-index) patient in the setup method.
        patient = @patient
        patient_identifier = patient.identifier[0].value

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_include' => 'Condition.patient'
            }
          }
        }
        reply = @client.search(FHIR::Condition, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.total > 0, 'The server should have Conditions with _include=Condition.patient.'
      end

      test 'SE21', 'Search for quantity (in observation) - precision tests' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#4.20.6"
          validates resource: "Observation", methods: ["search"]
        }
        skip unless (@obs_a && @obs_b && @obs_c)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'value-quantity' => '4.1234||mmol'
            }
          }
        }
        reply = @client.search(FHIR::Observation, options)
        has_obs_a = has_obs_b = has_obs_c = false
        while reply != nil
          assert_response_ok(reply)
          assert_bundle_response(reply)
          has_obs_a = true if reply.resource.get_by_id(@obs_a)
          has_obs_b = true if reply.resource.get_by_id(@obs_b)
          has_obs_c = true if reply.resource.get_by_id(@obs_c)
          reply = @client.next_page(reply)
        end

        assert has_obs_a,  'Search on quantity value 4.1234 should return 4.12345'
        assert !has_obs_b, 'Search on quantity value 4.1234 should not return 4.12346'
        assert !has_obs_c, 'Search on quantity value 4.1234 should not return 4.12349'
      end

      test 'SE22', 'Search for quantity (in observation) - operators' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#4.20.6"
          validates resource: "Observation", methods: ["search"]
        }
        skip unless (@obs_a && @obs_d && @obs_e)

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'value-quantity' => '>5||mmol'
            }
          }
        }
        reply = @client.search(FHIR::Observation, options)
        has_obs_a = has_obs_b = has_obs_c = false
        while reply != nil
          assert_response_ok(reply)
          assert_bundle_response(reply)
          has_obs_a = true if reply.resource.get_by_id(@obs_a)
          has_obs_d = true if reply.resource.get_by_id(@obs_d)
          has_obs_e = true if reply.resource.get_by_id(@obs_e)
          reply = @client.next_page(reply)
        end

        assert !has_obs_a,  'Search greater than quantity should not return lesser value.'
        assert has_obs_d, 'Search greater than quantity should return greater value.'
        assert has_obs_e, 'Search greater than quantity should return greater value.'
      end

      test 'SE23', 'Search with quantifier :missing, on Patient.gender' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#5.1.8"
          validates resource: "Patient", methods: ["search"]
        }
        skip unless @read_entire_feed
        # how many patients in the bundle have no gender?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          expected += 1 if !patient.nil? && patient.gender.nil?
        end

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'gender:missing' => true
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the correct number of results.'
      end

      test 'SE24', 'Search with non-existing parameter' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#5.1.8"
          validates resource: "Patient", methods: ["search"]
        }
        # non-existing parameters should be ignored
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'bonkers' => 'foobar'
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test 'SE25', 'Search with malformed parameters' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#5.1.8"
          validates resource: "Patient", methods: ["search"]
        }
        # a malformed parameters are non-existing parameters, and they should be ignored
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '...' => 'foobar'
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

    end
  end
end
