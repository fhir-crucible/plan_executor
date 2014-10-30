module Crucible
  module Tests
    class ResourceTest < BaseTest

      attr_accessor :resource_class
      attr_accessor :bundle
      attr_accessor :temp_resource

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
        @temp_resource = ResourceGenerator.generate(@resource_class,true)

        response = @client.create @temp_resource

        if response[:response].code==201
          result.update('passed', 'New #{resource_class.name.demodulize} was created.', response[:response].body)
        else
          outcome = self.parse_operation_outcome(response[:response].body)
          message = self.build_messages(outcome)
          result.update('failed', message, response[:response].body)
          @temp_resource = nil
        end

        result
      end

      #
      # Test if we can read a preexisting resource (only works if a bundle was retrieved successfully in X000)
      #
      def read_test
        result = TestResult.new('X020',"Read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        if !@bundle.nil? and @bundle.size>0
          preexisting_id = @bundle.get(1).id
          preexisting_id = preexisting_id.split('/').last    
        elsif !@temp_resource.nil?
          preexisting_id = @temp_resource.id
        else
          return result.update('failed', "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

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

        if !@bundle.nil? and @bundle.size>0
          preexisting_id = @bundle.get(1).id
          preexisting_id = preexisting_id.split('/').last
          preexisting = @bundle.get(1).resource    
        elsif !@temp_resource.nil?
          preexisting_id = @temp_resource.id
          preexisting = @temp_resource
        else
          return result.update('failed', "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        if preexisting.nil?
          result.update('failed', "Unable to update -- no existing #{resource_class.name.demodulize} is available or could be created.", nil)
        else
          ResourceGenerator.set_fields!(preexisting)

          response = @client.update preexisting, preexisting_id

          if response[:response].code==200
            result.update('passed', "Updated existing #{resource_class.name.demodulize}.", response[:response].body)
          elsif response[:response].code==201
            result.update('failed', "Server created new #{resource_class.name.demodulize} rather than update.", response[:response].body)
          else
            outcome = self.parse_operation_outcome(response[:response].body)
            message = self.build_messages(outcome)
            result.update('failed', message, response[:response].body)
          end
        end

        result
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
