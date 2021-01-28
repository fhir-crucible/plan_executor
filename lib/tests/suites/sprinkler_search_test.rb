module Crucible
  module Tests
    class SprinklerSearchTest < BaseSuite

      attr_accessor :use_post

      def id
        'Search001'
      end

      def description
        'Initial Sprinkler tests for testing search capabilities.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # Create a patient with gender:missing
        @resources = Crucible::Generator::Resources.new(fhir_version)
        @patient = @resources.minimal_patient
        @patient.identifier = [get_resource(:Identifier).new]
        @patient.identifier[0].value = SecureRandom.urlsafe_base64
        @patient.gender = nil
        result = @client.create(@patient)
        @patient_id = result.id

        # read all the patients
        @read_entire_feed=true
        @client.use_format_param = true
        reply = @client.read_feed(get_resource(:Patient))
        @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        @total_count = 0
        @entries = []

        mute_response_body 'The body of the Sprinkler Search setup responses are not stored for performance reasons.' do
          while reply != nil && !reply.resource.nil?
            @total_count += reply.resource.entry.size
            @entries += reply.resource.entry
            reply = @client.next_page(reply)
            @read_entire_feed=false if (!reply.nil? && reply.code!=200)
          end
        end

        # create a condition matching the first patient
        @condition = ResourceGenerator.generate(get_resource(:Condition),3)
        if fhir_version == :dstu2
          @condition.patient = @entries.first.try(:resource).try(:to_reference)
        else
          @condition.subject = @entries.first.try(:resource).try(:to_reference)
        end

        reply = @client.create(@condition)
        @condition_id = reply.id

        # create some observations
        @obs_a = create_observation(2.0)
        @obs_b = create_observation(1.96)
        @obs_c = create_observation(2.04)
        @obs_d = create_observation(1.80)
        @obs_e = create_observation(5.12)
        @obs_f = create_observation(6.12)
      end

      def create_observation(value)
        observation = get_resource(:Observation).new
        observation.status = 'preliminary'
        code = get_resource(:Coding).new
        code.system = 'http://loinc.org'
        code.code = '2164-2'
        observation.code = get_resource(:CodeableConcept).new
        observation.code.coding = [ code ]
        observation.valueQuantity = get_resource(:Quantity).new
        observation.valueQuantity.system = 'http://unitsofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.unit = 'mmol'
        body = get_resource(:Coding).new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySite = get_resource(:CodeableConcept).new
        observation.bodySite.coding = [ body ]
        Crucible::Generator::Resources.new(fhir_version).tag_metadata(observation)
        reply = @client.create(observation)
        reply.id
      end

      def teardown
        @client.use_format_param = false
        @client.destroy(get_resource(:Patient), @patient_id) if @patient_id
        @client.destroy(get_resource(:Condition), @condition_id) if @condition_id
        @client.destroy(get_resource(:Observation), @obs_a) if @obs_a
        @client.destroy(get_resource(:Observation), @obs_b) if @obs_b
        @client.destroy(get_resource(:Observation), @obs_c) if @obs_c
        @client.destroy(get_resource(:Observation), @obs_d) if @obs_d
        @client.destroy(get_resource(:Observation), @obs_e) if @obs_e
        @client.destroy(get_resource(:Observation), @obs_f) if @obs_f
      end
 
    [true,false].each do |flag|  
      action = 'GET'
      action = 'POST' if flag

      test "SE01#{action[0]}",'Search patients without criteria (except _count)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          validates resource: "Patient", methods: ["search"]
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_count' => '1'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.entry.size, 'The server did not return the correct number of results.'
      end

      test "SE02#{action[0]}", 'Search on non-existing resource' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
        }
        options = {
          :resource => Crucible::Tests::SprinklerSearchTest,
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search_all(options)
        assert( (reply.code >= 400 && reply.code < 600), 'If the search fails, the return value should be status code 4xx or 5xx.', reply)
      end

      test "SE03#{action[0]}",'Search patient resource on partial family surname' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        search_string = ''
        if fhir_version == :dstu2
          search_string = @patient.name[0].family.first[0..2]
        else
          search_string = @patient.name[0].family[0..2]
        end
        search_regex = Regexp.new(search_string, Regexp::IGNORECASE)
        # how many patients in the bundle have matching names?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          isMatch = false
          if !patient.nil? && !patient.name.nil?
            patient.name.each do |name|
              if !name.family.nil?
                if !(name.family =~ search_regex).nil?
                  isMatch = true
                end
              end
            end
          end
          expected += 1 if isMatch
        end

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'family' => search_string
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the expected number of results.'
      end

      test "SE04#{action[0]}", 'Search patient resource on given name' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        search_string = @patient.name[0].given[0]
        search_regex = Regexp.new(search_string, Regexp::IGNORECASE)
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
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'given' => search_string
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the expected number of results.'
      end

      test "SE05.0#{action[0]}", 'Search condition by patient reference url (partial)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => @entries.first.resource.to_reference.reference
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.0F#{action[0]}", 'Search condition by patient reference url (full)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        options = {
          :id => @entries[0].resource.id,
          :resource => @entries[0].resource.class
        }
        temp = @client.use_format_param
        @client.use_format_param = false
        patient_url = @client.full_resource_url(options)
        @client.use_format_param = temp

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => patient_url
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.1#{action[0]}", 'Search condition by patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        patient_id = @entries[0].resource.id

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.2#{action[0]}", 'Search condition by patient:Patient reference url' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        options = {
          :id => @entries[0].resource.id,
          :resource => @entries[0].resource.class
        }
        temp = @client.use_format_param
        @client.use_format_param = false
        patient_url = @client.resource_url(options)
        patient_url = patient_url[1..-1] if patient_url[0]=='/'
        @client.use_format_param = temp
       
        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_url
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.3#{action[0]}", 'Search condition by patient:Patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        patient = @entries[0].resource
        patient_id = @entries[0].resource.id

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.4#{action[0]}", 'Search condition by patient:_id reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        patient_id = @entries[0].resource.id

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient._id' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.5#{action[0]}", 'Search condition by patient.name reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # pick some search parameters... we previously created
        patient_name = @patient.name[0].family

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient.name' => patient_name
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE05.6#{action[0]}", 'Search condition by patient.identifier reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not create a patient in setup.' unless @patient_id
        # pick some search parameters... we previously created
        patient_identifier = @patient.identifier[0].value

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient.identifier' => patient_identifier
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        reply.resource.entry.each do |e|
          if fhir_version == :dstu2
            assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          else
            assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
          end
        end
      end

      test "SE06#{action[0]}", 'Search condition and _include' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        skip 'Could not create Condition in setup.' unless @condition_id

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_include' => 'Condition:patient',
              '_id' => @condition_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.total > 0, 'The server should have Conditions that _include=Condition:patient.'
        has_patient = false
        reply.resource.entry.each do |entry|
          has_patient = true if (entry.resource && entry.resource.class == get_resource(:Patient))
        end
        assert(has_patient,'The server did not include the Patient referenced in the Condition.', reply.body)
      end

      test "SE07#{action[0]}", 'Search patient and _revinclude' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        skip 'Could not create a patient in setup.' unless @patient_id

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_revinclude' => 'Condition:patient',
              '_id' => @patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.total > 0, 'The server should have Patients that are _revinclude=Condition:patient.'
        has_condition = false
        reply.resource.entry.each do |entry|
          has_condition = true if (entry.resource && entry.resource.class == get_resource(:Condition))
        end
        assert(has_condition,'The server did not include the Condition referencing the Patient.', reply.body)
      end

      test "SE21#{action[0]}", 'Search for quantity (in observation) - precision tests' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#search"
          validates resource: "Observation", methods: ["search"]
        }
        skip 'Could not create Observations in setup.' unless (@obs_a && @obs_b && @obs_c && @obs_d)

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'value-quantity' => '2.0||mmol'
            }
          }
        }
        reply = @client.search(get_resource(:Observation), options)
        has_obs_a = has_obs_b = has_obs_c = has_obs_d = false
        while reply != nil
          assert_response_ok(reply)
          assert_bundle_response(reply)
          has_obs_a = true if reply.resource.get_by_id(@obs_a)
          has_obs_b = true if reply.resource.get_by_id(@obs_b)
          has_obs_c = true if reply.resource.get_by_id(@obs_c)
          has_obs_d = true if reply.resource.get_by_id(@obs_d)          
          reply = @client.next_page(reply)
        end

        assert has_obs_a,  'Search on quantity value 2.0 should return 2.0'
        assert has_obs_b, 'Search on quantity value 2.0 should return 1.96'
        assert has_obs_c, 'Search on quantity value 2.0 should return 2.04'
        assert !has_obs_d, 'Search on quantity value 2.0 should not return 1.80'
      end

      test "SE22#{action[0]}", 'Search for quantity (in observation) - operators' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#search"
          validates resource: "Observation", methods: ["search"]
        }
        skip 'Could not create Observations in setup.' unless (@obs_a && @obs_e && @obs_f)

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'value-quantity' => 'gt5||mmol'
            }
          }
        }
        reply = @client.search(get_resource(:Observation), options)
        has_obs_e = has_obs_f = false
        while reply != nil
          assert_response_ok(reply)
          assert_bundle_response(reply)
          reply.resource.entry.each do |e|
            value = e.resource.value.try(:value)
            assert(value, "Search did not return a value.")
            assert((value > 5), "Search should not return values less than or equal to 5.")
          end
          has_obs_e = true if reply.resource.get_by_id(@obs_e)
          has_obs_f = true if reply.resource.get_by_id(@obs_f)
          reply = @client.next_page(reply)
        end

        assert has_obs_e, 'Search greater than quantity should return greater value.'
        assert has_obs_f, 'Search greater than quantity should return greater value.'
      end

      test "SE23#{action[0]}", 'Search with quantifier :missing, on Patient.gender' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
        # how many patients in the bundle have no gender?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          expected += 1 if !patient.nil? && patient.gender.nil?
        end

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'gender:missing' => true
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.total, 'The server did not report the expected number of results.'
      end

      test "SE24#{action[0]}", 'Search with non-existing parameter' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        # non-existing parameters should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'bonkers' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test "SE25#{action[0]}", 'Search with malformed parameters' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        # a malformed parameters are non-existing parameters, and they should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '...' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

    end # EOF [true,false].each

    end
  end
end
