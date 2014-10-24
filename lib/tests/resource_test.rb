module Crucible
  module Tests
    class ResourceTest < BaseTest

      attr_accessor :resource_class
      attr_accessor :bundle

      def id
        "ResourceTest#{resource_class}"
      end

      def description
        "Basic operations for FHIR #{resource_class.name.demodulize} resource (CREATE, READ, VREAD, UPDATE, DELETE, HISTORY, SEARCH, VALIDATE)"
      end



      def read_type_test
        result = TestResult.new('X000',"Read #{resource_class.name.demodulize}s", nil, nil, nil)
        @bundle = @client.read_feed(@resource_class)
        if @bundle.nil?
          return result.update('failed', 'Service did not respond with bundle.', nil)
        end
        result.update('passed', 'Service responded with bundle.', @bundle.raw_xml)
      end

      def create_test
        result = TestResult.new('X010',"Create new #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped creation of new #{resource_class.name.demodulize}.", nil)
      end

      def read_test
        result = TestResult.new('X020',"Read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        if @bundle.nil? or @bundle.size==0
          return result.update('failed', "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        preexisting_id = @bundle.get(1).id
        preexisting_id = preexisting_id.split('/').last
        resource = @client.read(@resource_class, preexisting_id)

        if resource.nil?
          return result.update('failed', "Failed to read preexisting #{resource_class.name.demodulize}.", nil)
        end

        result.update('passed', "Successfully read preexisting #{resource_class.name.demodulize}.", resource.to_xml)
      end

      def vread_test
        result = TestResult.new('X030',"Version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped version read preexisting #{resource_class.name.demodulize}.", nil)
      end

      def update_test
        result = TestResult.new('X040',"Update existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped updating preexisting #{resource_class.name.demodulize}.", nil)
      end

      def delete_test
        result = TestResult.new('X050',"Delete existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped deleting preexisting #{resource_class.name.demodulize}.", nil)
      end

      def history_test
        result = TestResult.new('X060',"Read history of existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped reading history of preexisting #{resource_class.name.demodulize}.", nil)
      end

      def search_test
        result = TestResult.new('X070',"Search for existing #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped searching for preexisting #{resource_class.name.demodulize}.", nil)
      end

      def validate_test
        result = TestResult.new('X080',"Validation of #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped validation of #{resource_class.name.demodulize}.", nil)
      end

    end
  end
end
