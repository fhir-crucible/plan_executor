module Crucible
  module Tests
    class ConnectathonPatientTrackTest < BaseSuite

      def id
        'Connectathon Patient Track'
      end

      def description
        'Connectathon Patient Track tests: registering, updating, history, and search'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = 'Connectathon'
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        @patient = @resources.example_patient
        @patient.xmlId = nil # clear the identifier, in case the server checks for duplicates
        @patient.identifier = nil # clear the identifier, in case the server checks for duplicates

        @patient_us = @resources.example_patient_us
        @patient_us.xmlId = nil # clear the identifier, in case the server checks for duplicates
        @patient_us.identifier = nil # clear the identifier, in case the server checks for duplicates
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient_id) if !@patient_id.nil?
        @client.destroy(FHIR::Patient, @patient_us_id) if !@patient_us_id.nil?
      end

      #
      # Test if we can create a new Patient.
      #
      test 'C8T1_1A','Register a new patient' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#1._Register_a_new_patient'
          requires resource: 'Patient', methods: ['create']
          validates resource: 'Patient', methods: ['create']
        }

        reply = @client.create @patient
        @patient_id = reply.id
        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can create a new Patient with US Extensions.
      #
      test 'C8T1_1B','Register a new patient - BONUS: Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#1._Register_a_new_patient'
          requires resource: 'Patient', methods: ['create']
          validates resource: 'Patient', methods: ['create']
          validates extensions: ['extensions']
        }

        reply = @client.create @patient_us
        @patient_us_id = reply.id
		    @patient_us.xmlId = reply.resource.xmlId || reply.id

        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can update a patient.
      #
      test 'C8T1_2A','Update a patient' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Update_a_patient'
          requires resource: 'Patient', methods: ['create', 'update']
          validates resource: 'Patient', methods: ['update']
        }
        skip unless @patient_id

		    @patient.xmlId = @patient_id
        @patient.telecom[0].value='1-800-TOLL-FREE'
        @patient.telecom[0].system='phone'
        @patient.name[0].given = ['Crocodile','Pants']

        reply = @client.update @patient, @patient_id

        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can update a patient with unmodified extensions.
      #
      test 'C8T1_2B','Update a patient - BONUS: Unmodifier Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Update_a_patient'
          requires resource: 'Patient', methods: ['create','update']
          validates resource: 'Patient', methods: ['update']
          validates extensions: ['extensions']
        }
        skip unless @patient_us_id
		
        @patient_us.xmlId = @patient_us_id
        @patient_us.extension[0].value.value.coding[0].code = '1569-3'
        @patient_us.extension[1].value.value.coding[0].code = '2186-5'

        reply = @client.update @patient_us, @patient_us_id
        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can update a patient with modified extensions.
      #
      test 'C8T1_2C','Update a patient - BONUS: Modifier Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Update_a_patient'
          requires resource: 'Patient', methods: ['create','update']
          validates resource: 'Patient', methods: ['update']
          validates extensions: ['modifying extensions']
        }
        skip unless @patient_us_id

		    @patient_us.xmlId = @patient_us_id
        @patient_us.modifierExtension << FHIR::Extension.new
        @patient_us.modifierExtension[0].url='http://projectcrucible.org/modifierExtension/foo'
        @patient_us.modifierExtension[0].value = FHIR::AnyType.new('Boolean',true)

        reply = @client.update @patient_us, @patient_us_id

        @patient_us.modifierExtension.clear

        assert([200,201,422].include?(reply.code), 'The server should except a modifierExtension, or return 422 if it chooses to reject a modifierExtension it does not understand.',"Server response code: #{reply.code}\n#{reply.body}")

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can update a patient with primitive extensions.
      #
      test 'C8T1_2D','Update a patient - BONUS: Primitive Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Update_a_patient'
          requires resource: 'Patient', methods: ['create','update']
          validates resource: 'Patient', methods: ['update']
          validates extensions: ['primitive extensions']
        }
        skip unless @patient_us_id

        @patient_us.xmlId = @patient_us_id
        @patient_us.gender = 'male'
        pe = FHIR::PrimitiveExtension.new
        pe.path='_gender'
        pe['extension'] = [ FHIR::Extension.new ]
        pe['extension'][0].url = 'http://hl7.org/test/gender'
        pe['extension'][0].value = FHIR::AnyType.new('String','Male')
        @patient_us.primitiveExtension << pe

        reply = @client.update @patient_us, @patient_us_id

        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if we can update a patient with complex extensions.
      #
      test 'C8T1_2E','Update a patient - BONUS: Complex Extensions' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Update_a_patient'
          requires resource: 'Patient', methods: ['create','update']
          validates resource: 'Patient', methods: ['update']
          validates extensions: ['complex extensions']
        }
        skip unless @patient_us_id

        @patient_us.xmlId = @patient_us_id
        begin
          @patient_us.primitiveExtension.clear
        rescue Exception => e
          # IGNORE: the above call always throws an exception -- even though it succeeds!!
        end
        ext = FHIR::Extension.new
        ext.url = 'http://hl7.org/complex/foo'
        ext.extension << FHIR::Extension.new
        ext.extension[0].url='http://complex/foo/bar'
        ext.extension[0].value=FHIR::AnyType.new('String','foobar')
        @patient.extension << ext

        reply = @client.update @patient_us, @patient_us_id

        assert_response_ok(reply)

        if !reply.resource.nil?
          temp = reply.resource.xmlId
          reply.resource.xmlId = nil
          warning { assert @patient.equals?(reply.resource), 'The server did not correctly preserve the Patient data.' }
          reply.resource.xmlId = temp
        end

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

      #
      # Test if can retrieve patient history
      #
      test  'C8T1_3','Retrieve Patient History' do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#3._Retrieve_Patient_history'
          requires resource: 'Patient', methods: ['create', 'update']
          validates resource: 'Patient', methods: ['history']
        }
        skip unless @patient_id

        result = @client.resource_instance_history(FHIR::Patient,@patient_id)
        assert_response_ok result
        assert_equal 2, result.resource.total, 'The number of returned versions is not correct'
        warning { assert_equal 'history', result.resource.fhirType, 'The bundle does not have the correct type: history' }
        warning { check_sort_order(result.resource.entry) }
      end

      def check_sort_order(entries)
        entries.each_cons(2) do |left, right|
          assert !left.resource.meta.nil?, 'Unable to determine if entries are in the correct order -- no meta'
          assert !right.resource.meta.nil?, 'Unable to determine if entries are in the correct order -- no meta'

          if !left.resource.meta.versionId.nil? && !right.resource.meta.versionId.nil?
            assert (left.resource.meta.versionId > right.resource.meta.versionId), 'Result contains entries in the wrong order.'
          elsif !left.resource.meta.lastUpdated.nil? && !right.resource.meta.lastUpdated.nil?
            assert (left.resource.meta.lastUpdated >= right.resource.meta.lastUpdated), 'Result contains entries in the wrong order.'
          else
            raise AssertionException.new 'Unable to determine if entries are in the correct order -- no meta.versionId or meta.lastUpdated'
          end
        end
      end

      #
      # Search for a patient on name
      #
      test 'C8T1_4', 'Search patient resource on given name' do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          links "#{BASE_SPEC_LINK}/search.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#4._Search_for_a_patient_on_name'
          requires resource: 'Patient', methods: ['create']
          validates resource: 'Patient', methods: ['search']
        }

        search_string = @patient.name[0].given[0]
        search_regex = Regexp.new(search_string)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'given' => search_string
            }
          }
        }
        @client.use_format_param = false
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (reply.resource.total > 0), 'The server did not report any results.'
      end

    end
  end
end
