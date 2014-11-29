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
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient

        create_date = Time.now
        result = @client.create(@patient)

        @id = result.id
        @patient.id = @id
      end

      test 'CT01', 'Request xml using headers' do
        setup

        begin
          patient = @client.read(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML)
          patient.resource.id = @id

          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested XML (headers) resource does not match created resource'
        rescue
          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested XML (headers) resource could not be parsed'
        end
      end

      test 'CT02', 'Request xml using [_format]' do
        setup

        @client.use_format_param = true

        begin
          patient = @client.read(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_XML)
          patient.resource.id = @id

          @client.use_format_param = false

          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested XML (_format) resource does not match created resource'
        rescue
          @client.use_format_param = false
          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested XML (_format) resource could not be parsed'
        end
      end

      test 'CT03', 'Request json using headers' do
        setup

        begin
          patient = @client.read(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)
          patient.resource.id = @id

          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested JSON (headers) resource does not match created resource'
        rescue
          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested JSON (headers) resource could not be parsed'
        end
      end

      test 'CT04', 'Request json using [_format]' do
        setup

        @client.use_format_param = true

        begin
          patient = @client.read(FHIR::Patient, @id, FHIR::Formats::ResourceFormat::RESOURCE_JSON)
          patient.resource.id = @id

          @client.use_format_param = false

          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested JSON (_format) resource does not match created resource'
        rescue
          @client.use_format_param = false
          assert patient != nil && patient.resource != nil && patient.resource == @patient, 'requested JSON (_format) resource could not be parsed'
        end
      end

    end
  end
end