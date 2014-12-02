module Crucible
  module Tests
    class FormatTest < BaseTest

      def id
        'Format001'
      end

      def description
        'Initial Sprinkler tests (CT01, CT02, CT03, CT04) for testing resource format requests.'
      end

      def setup
        @resources ||= Crucible::Generator::Resources.new
        @resource ||= @resources.example_patient

        create_date ||= Time.now
        result ||= @client.create(@resource)

        assert !result.id.blank?, 'failed to create resource on server'

        @id ||= result.id
        @resource.id = @id
      end

      test 'CT01', 'Request xml using headers' do
        setup

        begin
          patient = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML)
          assert compare_resource(patient), 'requested XML (headers) resource does not match created resource'
        rescue
          assert compare_resource(patient), 'requested XML (headers) resource could not be parsed'
        end
      end

      test 'CT02', 'Request xml using [_format]' do
        setup

        begin
          patient = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML, true)
          assert compare_resource(patient), 'requested XML (_format) resource does not match created resource'
        rescue
          @client.use_format_param = false
          assert compare_resource(patient), 'requested XML (_format) resource could not be parsed'
        end
      end

      test 'CT03', 'Request json using headers' do
        setup

        begin
          patient = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)
          assert compare_resource(patient), 'requested JSON (headers) resource does not match created resource'
        rescue
          assert compare_resource(patient), 'requested JSON (headers) resource could not be parsed'
        end
      end

      test 'CT04', 'Request json using [_format]' do
        setup

        begin
          patient = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON, true)
          assert compare_resource(patient), 'requested JSON (_format) resource does not match created resource'
        rescue
          @client.use_format_param = false
          assert compare_resource(patient), 'requested JSON (_format) resource could not be parsed'
        end
      end

      test 'FT01', 'Request xml and json using headers' do
        setup

        begin
          patient_xml = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML)
          patient_json = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)

          assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (headers) resources do not match created resource or each other'
        rescue
          @client.use_format_param = false
          assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (headers) resources could not be parsed'
        end
      end

      test 'FT02', 'Request xml and json using [_format]' do
        setup

        begin
          patient_xml = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML, true)
          patient_json = request_entry(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON, true)

          assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (_format) resources do not match created resource or each other'
        rescue
          @client.use_format_param = false
          assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (_format) resources could not be parsed'
        end
      end

      test 'FT03', 'Request xml feed using headers' do
        setup

        begin
          patients_feed = request_feed(FHIR::Patient, FHIR::Formats::FeedFormat::FEED_XML)
          bundle = patients_feed.resource
          patient = bundle.get_by_id(@id)

          # FIXME: Can we retrieve the patient from the Bundle?
          assert !patients_feed.blank?, 'requested XML (headers) feed does not contain created resource'
        rescue
          assert !patients_feed.blank?, 'requested XML (headers) feed could not be parsed'
        end
      end

      test 'FT04', 'Request xml feed using [_format]' do
        setup

        begin
          patients_feed = request_feed(FHIR::Patient, FHIR::Formats::FeedFormat::FEED_XML, true)
          bundle = patients_feed.resource
          patient = bundle.get_by_id(@id)

          # FIXME: Can we retrieve the patient from the Bundle?
          assert !patients_feed.blank?, 'requested XML (_format) feed does not contain created resource'
        rescue
          assert !patients_feed.blank?, 'requested XML (_format) feed could not be parsed'
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