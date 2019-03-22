module Crucible
  module Tests
    class HistoryTest < BaseSuite

      def id
        'History001'
      end

      def description
        'Initial Sprinkler tests (HI01,HI02,HI03,HI04,HI05,HI06,HI07,HI08,HI09,HI10,HI11) for testing resource history requests.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        begin
          @resources = Crucible::Generator::Resources.new(fhir_version)
          response = @client.create(@resources.minimal_patient)
          assert_response_ok(response)
          assert_resource_type(response, get_resource(:Patient))
          @patient = response.resource
          @patient_created = true
          @create_date = Time.now.utc

          @version = []
          @version << @client.reply.version

          @patient.telecom ||= []
          @patient.telecom << get_resource(:ContactPoint).new.from_hash(system: 'email', value: 'foo@example.com')

          @patient.update
          @version << @client.reply.version
          @patient.destroy
          assert([200,204].include?(@client.reply.code), 'The server should have returned a 200 or 204 upon successful deletion.')

          @entry_count = @version.length
          # add one for deletion
          @version_count = @entry_count + 1
          @patient_setup = true
        rescue Exception => e
          @patient_setup = false
          @create_date = Time.now.utc
        end
      end

      def teardown
        ignore_client_exception { @patient.destroy if @patient_created }
      end

      test  'HI01','History for specific resource' do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history"]
        }
        skip 'Patient not correctly created in setup.' unless @patient_setup

        bundle = get_resource(:Patient).resource_instance_history(@patient.id)

        assert_equal "history", bundle.type, "The bundle type is not correct"
        assert_equal @version_count, bundle.total, "the number of returned versions is not correct"
        check_sort_order(bundle.entry)
      end

      test  'HI01.1','History request entries' do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history"]
        }
        skip 'Patient not correctly created in setup.' unless @patient_setup
        bundle = get_resource(:Patient).resource_instance_history(@patient.id)
        entries = bundle.entry

        assert_equal 1, entries.select{|entry| entry.request.try(:local_method) == 'DELETE' }.size, 'Wrong number of DELETE transactions in the history bundle'
        assert_equal 1, entries.select{|entry| entry.request.try(:local_method) == 'PUT' }.size, 'Wrong number of PUT transactions in the history bundle'
        assert_equal 1, entries.select{|entry| entry.request.try(:local_method) == 'POST' }.size, 'Wrong number of POST transactions in the history bundle'

      end

      test "HI02", "full history of a resource by id with since" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history"]
        }
        skip 'Patient not correctly created in setup.' unless @patient_setup

        before = @create_date - 1.minute
        after = before + 1.hour

        all_history = get_resource(:Patient).resource_instance_history(@patient.id)

        bundle = get_resource(:Patient).resource_instance_history_as_of(@patient.id,before)
        assert (!bundle.nil? && bundle.class == get_resource(:Bundle)), "Patient history should be a Bundle"
        assert_equal @version_count, bundle.total, "the number of returned versions since the creation date is not correct"

        entry_ids_are_present(bundle.entry)
        check_sort_order(bundle.entry)

        bundle = get_resource(:Patient).resource_instance_history_as_of(@patient.id,after)
        assert_equal 0, bundle.total, "there should not be any history one hour after the creation date"
      end

      test "HI03", "individual history versions" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["vread", "history"]
        }
        skip 'Patient not correctly created in setup.' unless @patient_setup

        bundle = get_resource(:Patient).resource_instance_history(@patient.id)

        active_entries(bundle.entry).each do |entry|
          pulled = get_resource(:Patient).vread(entry.resource.id, entry.resource.meta.versionId)
          assert !pulled.nil?, "Cannot find version that was present in history"
        end

        deleted_entries(bundle.entry).each do |entry|
          # FIXME: Should we parse the request URL or drop this assertion?
          if entry.resource

            ignore_client_exception { pulled = get_resource(:Patient).vread(entry.resource.id, entry.resource.meta.versionId) }
            assert_response_gone @client.reply

          end
        end
      end

      test "HI04", "history for missing resource" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history"]
        }

        ignore_client_exception { get_resource(:Patient).resource_instance_history('3141592unlikely') }
        assert_response_not_found @client.reply
        assert @client.reply.resource.nil?, 'bad history request should not return a resource'
      end

      test "HI06", "all history for resource with since" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        before = @create_date - 1.minute
        after = Time.now.utc + 1.hour

        bundle = get_resource(:Patient).resource_history_as_of(before)
        assert (!bundle.nil? && bundle.class == get_resource(:Bundle)), "History should be a Bundle"

        entry_ids_are_present(bundle.entry)
        check_sort_order(bundle.entry)

        bundle = get_resource(:Patient).resource_history_as_of(after)
        assert_equal 0, bundle.total, "Setting since to a future moment still returns history"

      end

      test "HI08", "all history whole system with since" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: nil, methods: ["history-system"]
        }

        before = @create_date - 1.minute
        after = Time.now.utc + 1.hour

        result = @client.all_history_as_of(before)
        assert_response_ok result
        bundle = result.resource
        assert (!bundle.nil? && bundle.class == get_resource(:Bundle)), "History should be a Bundle"
        entry_ids_are_present(bundle.entry)

        relevant_entries = bundle.entry.select{|x|x.request.try(:local_method)!='DELETE'}
        relevant_entries.map!(&:resource).map!(&:meta).compact rescue assert(false, 'Unable to find meta for resources returned by the bundle')
        relevant_entries.each_cons(2) do |left, right|
          if !left.lastUpdated.nil? && !right.lastUpdated.nil?
            assert (left.lastUpdated >= right.lastUpdated), 'Result contains entries in the wrong order.'
          else
            raise AssertionException.new 'Unable to determine if entries are in the correct order -- no meta.versionId or meta.lastUpdated'
          end
        end

        result = @client.resource_history_as_of(get_resource(:Patient),after)
        assert_response_ok result
        assert_equal 0, result.resource.total, "Setting since to a future moment still returns history"
      end


      test "HI09", "resource history page forward" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        page_size = 2
        page = @client.history(resource: get_resource(:Patient), history: {since: (Time.now.utc - 1.hour), count: page_size})

        forward_count = 0
        # browse forwards
        while page != nil
          assert !page.resource.nil?, "Unable to page forward through results.  A bundle was not returned from the page forward request."
          warning { entry_ids_are_present(page.resource.entry) }
          assert page.resource.entry.size <= page_size, "Server returned a page with more entries than set by _count"
          forward_count += page.resource.entry.size
          page = @client.next_page(page)
        end

        assert(forward_count > 2, "there should be at least 2 history entries") if @patient_setup
      end

      test "HI10", "resource history page backwards" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        page_size = 2
        page = @client.history(resource: get_resource(:Patient), history: {since: (Time.now.utc - 1.hour), count: page_size})

        forward_count = 0
        last_page = page
        # browse forwards
        while page != nil
          assert !page.resource.nil?, "Unable to page forward through results.  A bundle was not returned from the page forward request."
          forward_count += page.resource.entry.size
          page = @client.next_page(page)
          last_page = page if page
        end

        backward_count = 0
        page = last_page
        # browse backwards
        while page != nil
          warning { entry_ids_are_present(page.resource.entry) }
          assert page.resource.entry.size <= page_size, "Server returned a page with more entries than set by _count"
          backward_count += page.resource.entry.size
          page = @client.next_page(page, FHIR::Sections::Feed::BACKWARD)
        end

        assert_equal forward_count, backward_count, "entry numbers were different moving forwards and backwards"

      end

      test "HI11", "first page full history" do
        metadata {
          links "#{REST_SPEC_LINK}#history"
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: nil, methods: ["history-system"]
        }

        history = @client.all_history
        assert !history.resource.nil?, "A bundle was not returned from the history request."
        assert(history.resource.entry.size >= 3, "there should be at least 3 history entries") if @patient_setup
      end

      ###
      ### Test first and last pages
      ###


      ####
      #### Check sice with timezones?????
      ####

      def deleted_entries(entries)
        entries.select do |entry|
          assert !entry.request.nil?, "history bundle entries do not have request elements, deleted entries cannot be distinguished"
          entry.request.try(:local_method) == "DELETE"
        end
      end

      def active_entries(entries)
        entries - deleted_entries(entries)
      end


      def entry_ids_are_present(entries)
        relevant_entries = entries.select{|x|x.request.try(:local_method)!='DELETE'}
        ids = relevant_entries.map(&:resource).map(&:id).compact rescue assert(false, 'Unable to find IDs for resources returned by the bundle')

        # check that we have ids and self links
        assert_equal relevant_entries.length, ids.size, 'All PUT and POST entries must have an ID'
      end

      def url?(v)
        v =~ /\A#{URI::regexp}\z/
      end

      def check_sort_order(entries)
        relevant_entries = entries.select{|x|x.request.try(:local_method)!='DELETE'}
        relevant_entry_metas = relevant_entries.map(&:resource).map!(&:meta).compact rescue assert(false, 'Unable to find meta for resources returned by the bundle')

        id_version_map = {}

        relevant_entries.each do |entry|

          key =  "#{entry&.resource&.id} #{entry&.resource&.meta&.versionId}"

          assert !id_version_map.has_key?(key), "Resource with ID #{entry&.resource&.id} has multiple history elements with version id #{entry&.resource&.meta&.versionId}"
          id_version_map[key] = 1
        end

        relevant_entry_metas.each_cons(2) do |left, right|
          if !left.lastUpdated.nil? && !right.lastUpdated.nil?
            assert (left.lastUpdated >= right.lastUpdated), 'Result contains entries in the wrong order.'
          else
            raise AssertionException.new 'Unable to determine if entries are in the correct order -- no meta.versionId or meta.lastUpdated'
          end
        end
      end

    end
  end
end
