module Crucible
  module Tests
    class FormatTest < BaseSuite

      def id
        'Format001'
      end

      def description
        'Initial Sprinkler tests (CT01, CT02, CT03, CT04) for testing resource format requests.'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @resource = @resources.example_patient

        create_date = Time.now
        result = @client.create(@resource)

        assert_response_created result

        @id = result.id
        @resource.id = @id
        @xml_format = FHIR::Formats::ResourceFormat::RESOURCE_XML
        @json_format = FHIR::Formats::ResourceFormat::RESOURCE_JSON
      end

      test 'CT01', 'Request xml using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format)
          assert compare_resource_format(patient, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient.response_format}"
          # assert compare_resource(patient), 'requested XML (headers) resource does not match created resource'
        rescue => e
          raise AssertionException.new("CTO1 - Failed to handle XML format header response. Error: #{e.message}")
          # assert compare_resource(patient), 'requested XML (headers) resource could not be parsed'
        end
      end

      test 'CT02', 'Request xml using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format, true)
          assert compare_resource_format(patient, @xml_format), "XML format param mismatch: requested #{@xml_format}, received #{patient.response_format}"
          # assert compare_resource(patient), 'requested XML (_format) resource does not match created resource'
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
          # assert compare_resource(patient), 'requested XML (_format) resource could not be parsed'
        end
      end

      test 'CT03', 'Request json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format)
          assert compare_resource_format(patient, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient.response_format}"
          # assert compare_resource(patient), 'requested JSON (headers) resource does not match created resource'
        rescue => e
          raise AssertionException.new("CTO3 - Failed to handle JSON format header response. Error: #{e.message}")
          # assert compare_resource(patient), 'requested JSON (headers) resource could not be parsed'
        end
      end

      test 'CT04', 'Request json using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format, true)
          assert compare_resource_format(patient, @json_format), "JSON format param mismatch: requested #{@json_format}, received #{patient.response_format}"
          # assert compare_resource(patient), 'requested JSON (_format) resource does not match created resource'
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO4 - Failed to handle JSON format param response. Error: #{e.message}")
          # assert compare_resource(patient), 'requested JSON (_format) resource could not be parsed'
        end
      end

      test 'FT01', 'Request xml and json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          skip
          patient_xml = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML)
          patient_json = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)

          # assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (headers) resources do not match created resource or each other'
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FTO1 Fatal Error: #{e.message}")
          # assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (headers) resources could not be parsed'
        end
      end

      test 'FT02', 'Request xml and json using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          skip
          patient_xml = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML, true)
          patient_json = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON, true)

          # assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (_format) resources do not match created resource or each other'
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FTO2 Fatal Error: #{e.message}")
          # assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (_format) resources could not be parsed'
        end
      end

      test 'FT03', 'Request xml feed using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          skip
          patients_feed = request_feed(FHIR::Patient, FHIR::Formats::FeedFormat::FEED_XML)
          bundle = patients_feed.resource
          patient = bundle.get_by_id(@id)

          # FIXME: Can we retrieve the patient from the Bundle?
          # assert !patients_feed.blank?, 'requested XML (headers) feed does not contain created resource'
        rescue => e
          raise AssertionException.new("FTO3 Fatal Error: #{e.message}")
          # assert !patients_feed.blank?, 'requested XML (headers) feed could not be parsed'
        end
      end

      test 'FT04', 'Request xml feed using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#2.1.0.6"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read']
        }
        begin
          skip
          patients_feed = request_feed(FHIR::Patient, FHIR::Formats::FeedFormat::FEED_XML, true)
          bundle = patients_feed.resource
          patient = bundle.get_by_id(@id)

          # FIXME: Can we retrieve the patient from the Bundle?
          # assert !patients_feed.blank?, 'requested XML (_format) feed does not contain created resource'
        rescue => e
          raise AssertionException.new("FTO4 Fatal Error: #{e.message}")
          # assert !patients_feed.blank?, 'requested XML (_format) feed could not be parsed'
        end
      end

      test 'FT05', 'Request json feed using headers' do
        skip
      end

      test 'FT06', 'Request json feed using [_format]' do
        skip
      end

      private

      # Simplify assertion checks
      def compare_resource(entry)
        entry != nil && entry.resource != nil && entry.resource == @resource
      end

      def compare_resource_format(entry, requested_format)
        entry != nil && entry.resource != nil && entry.response_format == requested_format
      end

      def compare_entries(entry1, entry2)
        compare_resource(entry1) && compare_resource(entry2) && entry1.resource == entry2.resource
      end

      # Unify resource requests and format specification
      def request_entry(resource_class, id, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read(resource_class, id, format)
        entry.resource.id = id
        @client.use_format_param = false
        entry
      end

      def request_feed(resource_class, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read_feed(resource_class, format)
        @client.use_format_param = false
        entry
      end

    end
  end
end
