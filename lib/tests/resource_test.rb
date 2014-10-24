module Crucible
  module Tests
    class ResourceTest < BaseTest

      attr_accessor :resource_class
      attr_accessor :bundle

      def id
        "#{resource_class}ResourceTest"
      end

      def description
        "Basic operations for FHIR #{resource_class} resource (READ, VREAD, UPDATE, DELETE, HISTORY, SEARCH, VALIDATE)"
      end

      def read_type_test
        result = TestResult.new('X001',"Read #{resource_class}s", nil, nil, nil)
        @bundle = @client.read_feed(@resource_class)
        if @bundle.nil?
          return result.update('failed', 'Service did not respond with bundle.', nil)
        end
        result.update('passed', 'Service responded with bundle.', @bundle.raw_xml)
      end

      def read_test
        result = TestResult.new('X002',"Read existing #{resource_class} by ID", nil, nil, nil)
        if @bundle.nil? or @bundle.size==0
          return result.update('failed', "Preexisting #{resource_class} unknown.", nil)
        end

        preexisting_id = @bundle.get(1).id
        preexisting_id = preexisting_id.split('/').last
        resource = @client.read(@resource_class, preexisting_id)

        if resource.nil?
          return result.update('failed', "Failed to read preexisting #{resource_class}.", nil)
        end

        result.update('passed', "Successfully read preexisting #{resource_class}.", resource.to_xml)
      end

    end
  end
end
