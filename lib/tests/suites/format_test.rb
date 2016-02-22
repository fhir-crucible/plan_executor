module Crucible
  module Tests
    class FormatTest < BaseSuite

      def id
        'Format001'
      end

      def description
        'Initial Sprinkler tests (CT01, CT02, CT03, CT04) for testing resource format requests.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = 'Format'
      end

      # Create a patient and store its details for format requests
      def setup
        @xml_format = FHIR::Formats::ResourceFormat::RESOURCE_XML
        @json_format = FHIR::Formats::ResourceFormat::RESOURCE_JSON
        @xml_format_params = ['xml', 'text/xml', 'application/xml', @xml_format]
        @json_format_params = ['json', 'application/json', @json_format]
        @resources = Crucible::Generator::Resources.new
        @resource = @resources.minimal_patient
        @create_failed = false

        create_reply = @client.create(@resource)

        begin
          assert_response_created create_reply
          result = create_reply.resource
        rescue AssertionException
          @create_failed = true
        end

        if @create_failed
          # If create fails, pick one from the Patient Bundle
          begin
            bundle_reply = request_bundle(FHIR::Patient, @xml_format)
            assert_response_ok bundle_reply
            bundle_patient = bundle_reply.resource.entry.first.resource
            @id = bundle_patient.xmlId
            @create_failed = false
          rescue Exception
            @create_failed = true            
          end
        else
          @id = create_reply.id
        end

        assert(!@create_failed, 'Unable to create or read a patient.')
      end

      # Delete the reference patient if we created it
      def teardown
        @client.destroy(FHIR::Patient, @id) unless @create_failed
      end

      test 'CT01', 'Request xml using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format)
          assert compare_response_format(patient, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML (headers) resource does not match created resource' }
        rescue => e
          raise AssertionException.new("CTO1 - Failed to handle XML format header response. Error: #{e.message}")
        end
      end

      test 'CT02A', 'Request [xml] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format_params[0], true)
          assert compare_response_format(patient, @xml_format), "XML format param mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
        end
      end

      test 'CT02B', 'Request [text/xml] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format_params[1], true)
          assert compare_response_format(patient, @xml_format), "XML format param mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
        end
      end

      test 'CT02C', 'Request [application/xml] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format_params[2], true)
          assert compare_response_format(patient, @xml_format), "XML format param mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
        end
      end

      test 'CT02D', 'Request [application/xml+fhir] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @xml_format_params[3], true)
          assert compare_response_format(patient, @xml_format), "XML format param mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
        end
      end

      test 'CT03', 'Request json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format)
          assert compare_response_format(patient, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested JSON (headers) resource does not match created resource' }
        rescue => e
          raise AssertionException.new("CTO3 - Failed to handle JSON format header response. Error: #{e.message}")
        end
      end

      test 'CT04A', 'Request [json] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format_params[0], true)
          assert compare_response_format(patient, @json_format), "JSON format param mismatch: requested #{@json_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested JSON (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO4 - Failed to handle JSON format param response. Error: #{e.message}")
        end
      end

      test 'CT04C', 'Request [application/json] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format_params[1], true)
          assert compare_response_format(patient, @json_format), "JSON format param mismatch: requested #{@json_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested JSON (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO4 - Failed to handle JSON format param response. Error: #{e.message}")
        end
      end

      test 'CT04D', 'Request [application/json+fhir] using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patient = request_entry(FHIR::Patient, @id, @json_format_params[2], true)
          assert compare_response_format(patient, @json_format), "JSON format param mismatch: requested #{@json_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested JSON (_format) resource does not match created resource' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("CTO4 - Failed to handle JSON format param response. Error: #{e.message}")
        end
      end

      test 'FT01', 'Request xml and json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML','JSON']
        }
        begin
          patient_xml = request_entry(FHIR::Patient, @id, @xml_format)
          patient_json = request_entry(FHIR::Patient, @id, @json_format)

          assert compare_response_format(patient_xml, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient_xml.response_format}"
          assert compare_response_format(patient_json, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient_json.response_format}"
          warning { assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (headers) resources do not match created resource or each other' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FTO1 - Failed to handle XML & JSON header param response. Error: #{e.message}")
        end
      end

      test 'FT02', 'Request xml and json using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML','JSON']
        }
        begin
          patient_xml = request_entry(FHIR::Patient, @id, @xml_format, true)
          patient_json = request_entry(FHIR::Patient, @id, @json_format, true)

          assert compare_response_format(patient_xml, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient_xml.response_format}"
          assert compare_response_format(patient_json, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient_json.response_format}"
          warning { assert compare_entries(patient_xml, patient_json), 'requested XML & JSON (_format) resources do not match created resource or each other' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FTO2 - Failed to handle XML & JSON format param response. Error: #{e.message}")
        end
      end

      test 'FT03', 'Request xml Bundle using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @xml_format)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format header mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO3 - Failed to handle Bundle XML format header response. Error: #{e.message}")
        end
      end

      test 'FT04A', 'Request [xml] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @xml_format_params[0], true)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format param mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO4- Failed to handle Bundle XML format param response. Error: #{e.message}")
        end
      end

      test 'FT04B', 'Request [text/xml] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @xml_format_params[1], true)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format param mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO4- Failed to handle Bundle XML format param response. Error: #{e.message}")
        end
      end

      test 'FT04C', 'Request [application/xml] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @xml_format_params[2], true)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format param mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO4- Failed to handle Bundle XML format param response. Error: #{e.message}")
        end
      end

      test 'FT04D', 'Request [application/xml+fhir] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @xml_format_params[3], true)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format param mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO4- Failed to handle Bundle XML format param response. Error: #{e.message}")
        end
      end

      test 'FT05', 'Request json Bundle using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @json_format)

          assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format header mismatch: requested #{@json_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FT05 - Failed to handle Bundle JSON format header response. Error: #{e.message}")
        end
      end

      test 'FT06A', 'Request [json] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @json_format_params[0], true)

          assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format param mismatch: requested #{@json_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO6 - Failed to handle Bundle JSON format param response. Error: #{e.message}")
        end
      end

      test 'FT06C', 'Request [application/json] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @json_format_params[1], true)

          assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format param mismatch: requested #{@json_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO6 - Failed to handle Bundle JSON format param response. Error: #{e.message}")
        end
      end

      test 'FT06D', 'Request [application/json+fhir] Bundle using [_format]' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        begin
          patients_bundle = request_bundle(FHIR::Patient, @json_format_params[2], true)

          assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format param mismatch: requested #{@json_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FTO6 - Failed to handle Bundle JSON format param response. Error: #{e.message}")
        end
      end

      private

      # Compare requested resource with created resource
      def compare_response(entry)
        @create_failed || entry != nil && entry.resource != nil && entry.resource == @resource
      end

      # Compare response format with requested format
      def compare_response_format(entry, requested_format)
        entry != nil && entry.response != nil && entry.response_format == requested_format
      end

      # Compare two requested entries
      def compare_entries(entry1, entry2)
        @create_failed || compare_response(entry1) && compare_response(entry2) && entry1.resource == entry2.resource
      end

      # Unify resource requests and format specification
      def request_entry(resource_class, id, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read(resource_class, id, format)
        @client.use_format_param = false
        assert_response_ok entry, "Failed to retrieve resource: #{entry.request[:url]}"
        entry.resource.id = id
        entry
      end

      # Unify Bundle requests and format specification
      def request_bundle(resource_class, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read_feed(resource_class, format)
        @client.use_format_param = false
        assert_response_ok entry, "Failed to retrieve Bundle: #{entry.request[:url]}"
        entry
      end

    end
  end
end
