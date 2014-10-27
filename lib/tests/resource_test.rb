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

      #
      # Get and read all the resources of this type. Result is an XML ATOM bundle.
      #
      def read_type_test
        result = TestResult.new('X000',"Read #{resource_class.name.demodulize}s", nil, nil, nil)
        @bundle = @client.read_feed(@resource_class)
        if @bundle.nil?
          return result.update('failed', 'Service did not respond with bundle.', nil)
        end
        result.update('passed', 'Service responded with bundle.', @bundle.raw_xml)
      end

      #
      # Test if we can create a new resource and post it to the server.
      #
      def create_test
        result = TestResult.new('X010',"Create new #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped creation of new #{resource_class.name.demodulize}.", nil)
      end

      #
      # Test if we can read a preexisting resource (only works if a bundle was retrieved successfully in X000)
      #
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

      #
      # Test if we can read a specific version of a preexisting resource.
      #
      def vread_test
        result = TestResult.new('X030',"Version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped version read preexisting #{resource_class.name.demodulize}.", nil)
      end

      #
      # Test if we can update a preexisting resource.
      #
      def update_test
        result = TestResult.new('X040',"Update existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped updating preexisting #{resource_class.name.demodulize}.", nil)
      end

      #
      # Test if we can delete a preexisting resource.
      #
      def delete_test
        result = TestResult.new('X050',"Delete existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped deleting preexisting #{resource_class.name.demodulize}.", nil)
      end

      #
      # Test if we can retrieve the history of a preexisting resource.
      #
      def history_test
        result = TestResult.new('X060',"Read history of existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        result.update('skipped', "Skipped reading history of preexisting #{resource_class.name.demodulize}.", nil)
      end

      #
      # Test all of the search capabilities on a given resource:
      # - id
      # - parameters
      # - parameter modifiers (:missing, :exact, :text, :[type])
      # - numbers (= < <= > >= significant-digits)
      # - date (all of the permutations?)
      # - token
      # - quantities
      # - references
      # - chained parameters
      # - composite parameters
      # - text search logical operators
      # - tags, profile, security label
      # - _filter parameter
      # 
      # - result relevance
      # - result sorting (_sort parameter)
      # - result paging
      # - _include parameter
      # - _summary parameter
      # - result server conformance (report params actually used)
      # 
      # - advanced searching with "Query" or _query param
      #
      def search_test
        # TODO given the breadth and depth of complexity around searchs alone, should refactor elsewhere...
        result = TestResult.new('X070',"Search for existing #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped searching for preexisting #{resource_class.name.demodulize}.", nil)
      end

      #
      # Validate the representation of a given resource.
      #
      def validate_test
        result = TestResult.new('X080',"Validation of #{resource_class.name.demodulize}", nil, nil, nil)
        result.update('skipped', "Skipped validation of #{resource_class.name.demodulize}.", nil)
      end

    end
  end
end
