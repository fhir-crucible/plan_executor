module Crucible
  module Tests
    class HistoryTest < BaseSuite

      def id
        'History001'
      end

      def description
        'Initial Sprinkler tests (HI01,HI02,HI03,HI04,HI05,HI06,HI07,HI08,HI09,HI10,HI11) for testing resource history requests.'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient

        @create_date = Time.now.utc

        @version = []
        result = @client.create(@patient)
        @id = result.id
        @version << result.version

        @patient.telecom << FHIR::ContactPoint.new(system: 'email', value: 'foo@example.com')

        update_result = @client.update(@patient, @id)
        @version << update_result.version

        @client.destroy(FHIR::Patient, @id)

        @entry_count = @version.length
        # add one for deletion
        @version_count = @entry_count + 1

      end

      test  'HI01','History for specific resource' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-instance"]
        }

        result = @client.resource_instance_history(FHIR::Patient,@id)
        assert_response_ok result
        assert_equal @version_count, result.resource.total, "the number of returned versions is not correct"
        assert_equal @entry_count, result.resource.entry.map(&:self_link).size, "all of the returned entries must have a self link"
        check_sort_order(result.resource.entry)
      end

      test "HI02", "full history of a resource by id with since" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-instance"]
        }

        before = @create_date - 1.minute
        after = before + 1.hour

        all_history = @client.resource_instance_history(FHIR::Patient,@id)

        result = @client.resource_instance_history_as_of(FHIR::Patient,@id,before)
        assert_response_ok result
        assert_equal @version_count, result.resource.total, "the number of returned versions since the creation date is not correct"

        entry_ids_are_present_and_absolute_urls(result.resource.entry)
        check_sort_order(result.resource.entry)

        selfs = result.resource.entry.map(&:self_link).compact
        warning { assert_equal @entry_count, (all_history.resource.entry.select {|e| selfs.include? e.self_link}).size, "there are entries missing "}

        result = @client.resource_instance_history_as_of(FHIR::Patient,@id,after)
        assert_response_ok result
        assert_equal 0, result.resource.total, "there should not be any history one hour after the creation date"
      end

      test "HI03", "individual history versions" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["vread", "history-instance"]
        }

        result = @client.resource_instance_history(FHIR::Patient,@id)
        assert_response_ok result
        active_entries(result.resource.entry).each do |entry|
          pulled = @client.vread(FHIR::Patient, entry.resource_id, entry.resource_version)
          assert_response_ok pulled
          assert !pulled.nil?, "Cannot find version that was present in history"
          assert url?(pulled.self_link), "#{pulled.self_link} is not a valid url" if pulled.self_link
        end

        deleted_entries(result.resource.entry).each do |entry|
          pulled = @client.vread(FHIR::Patient, entry.resource_id, entry.resource_version)
          assert pulled.resource.nil?, "resource should not be found since it was deleted"
          assert_response_gone pulled
        end
      end

      test "HI04", "history for missing resource" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-instance"]
        }

        result = @client.resource_instance_history(FHIR::Patient,'3141592unlikely')
        assert_response_not_found result
        assert result.resource.nil?, 'bad history request should not return a resource'
      end

      test "HI06", "all history for resource with since" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        before = @create_date - 1.minute
        after = Time.now.utc + 1.minute

        result = @client.resource_history_as_of(FHIR::Patient,before)
        assert_response_ok result
        entry_ids_are_present_and_absolute_urls(result.resource.entry)
        check_sort_order(result.resource.entry)

        selfs = result.resource.entry.map(&:self_link).compact
        assert_equal result.resource.entry.size, selfs.size, "history with _since does not contain all versions of instance"

        result = @client.resource_history_as_of(FHIR::Patient,after)
        assert_response_ok result
        assert_equal 0, result.resource.total, "Setting since to a future moment still returns history"

      end

      test "HI08", "all history whole system with since" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: nil, methods: ["history-system"]
        }

        before = @create_date - 1.minute
        after = Time.now.utc + 1.minute

        result = @client.all_history_as_of(before)
        assert_response_ok result
        entry_ids_are_present_and_absolute_urls(result.resource.entry)
        check_sort_order(result.resource.entry)

        warning { assert_navigation_links(result.resource) }

        selfs = result.resource.entry.map(&:self_link).compact
        assert_equal result.resource.entry.size, selfs.size, "history with _since does not contain all versions of instance"

        result = @client.resource_history_as_of(FHIR::Patient,after)
        assert_response_ok result
        assert_equal 0, result.resource.total, "Setting since to a future moment still returns history"

      end


      test "HI09", "resource history page forward" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        page_size = 30
        page = @client.history(resource: FHIR::Patient, history: {since: (Time.now.utc - 1.hour), count: page_size})

        forward_count = 0
        # browse forwards
        while page != nil
          assert !page.resource.nil?, "Unable to page forward through results.  A bundle was not returned from the page forward request."
          warning { entry_ids_are_present_and_absolute_urls(page.resource.entry) }
          assert page.resource.entry.count <= page_size, "Server returned a page with more entries than set by _count"
          forward_count += page.resource.entry.count
          page = @client.next_page(page)
        end

        assert forward_count > 2, "there should be at least 2 history entries"
      end

      test "HI10", "resource history page backwards" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: "Patient", methods: ["history-type"]
        }

        page_size = 30
        page = @client.history(resource: FHIR::Patient, history: {since: (Time.now.utc - 1.hour), count: page_size})

        forward_count = 0
        last_page = page
        while page != nil
          assert !page.resource.nil?, "Unable to page forward through results.  A bundle was not returned from the page forward request."
          forward_count += page.resource.entry.count
          page = @client.next_page(page)
          last_page = page if page
        end

        backward_count = 0
        page = last_page
        # browse forwards
        while page != nil
          warning { entry_ids_are_present_and_absolute_urls(page.resource.entry) }
          assert page.resource.entry.count <= page_size, "Server returned a page with more entries than set by _count"
          backward_count += page.resource.entry.count
          page = @client.next_page(page, FHIR::Sections::Feed::BACKWARD)
        end

        assert_equal forward_count, backward_count, "entry numbers were different moving forwards and backwards"

      end

      test "HI11", "first page full history" do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#history'
          requires resource: "Patient", methods: ["create", "update", "delete"]
          validates resource: nil, methods: ["history-system"]
        }

        history = @client.all_history
        assert history.resource.entry.size > 2, "there should be at least 2 history entries"
      end

      ###
      ### Test first and last pages
      ###


      ####
      #### Check sice with timezones?????
      ####

      def deleted_entries(entries)
        entries.select {|x| x.fhirDeleted }
      end

      def active_entries(entries)
        entries.select {|x| x.fhirDeleted.nil? }
      end


      def entry_ids_are_present_and_absolute_urls(entries)
        # selfs = entries.select {|x| x.fhirDeleted.nil? }.map(&:self_link).compact
        ids = entries.map(&:xmlId).compact

        # check that we have ids and self links
        # warning { assert_equal entries.length, selfs.size, "all of the returned entries must have a self link" }
        assert_equal entries.length, ids.size, "all of the returned entries must have an id"

        # check that they are valid URIs
        # warning { assert_equal entries.length, (selfs.select {|e| url?(e) }).size, "all self links must be valid URIs" }
        assert_equal entries.length, (ids.select {|e| url?(e)}).size, "all ids must be valid URIs"
      end

      def url?(v)
        v =~ /\A#{URI::regexp}\z/
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

    end
  end
end
