module Crucible
  module Tests
    class ResourceTest < BaseTest

      attr_accessor :resource_class
      attr_accessor :bundle
      attr_accessor :history_bundle

      attr_accessor :temp_resource
      attr_accessor :temp_id
      attr_accessor :temp_version

      attr_accessor :preexisting_id
      attr_accessor :preexisting_version
      attr_accessor :preexisting

      def execute
        fhir_resources.map do | klass |
          @resource_class = klass
          {"ResourceTest_#{resource_class.name.demodulize}" => {
            test_file: test_name,
            tests: execute_resource
          }}
        end
      end

      def id
        "ResourceTest_#{resource_class}"
      end

      def description
        "Basic operations for FHIR #{resource_class.name.demodulize} resource (CREATE, READ, VREAD, UPDATE, DELETE, HISTORY, SEARCH, VALIDATE)"
      end

      def execute_resource()
        execute_test_methods()
      end

      def supplement_test_description(desc)
        "#{desc} #{resource_class.name.demodulize}"
      end

      #
      # Get and read all the resources of this type. Result is an XML ATOM bundle.
      #
      test 'X000', 'Read Type' do
        reply = @client.read_feed(@resource_class)
        @bundle = reply.resource
        assert !@bundle.nil?, 'Service did not respond with bundle.'
        TestResult.new('','', STATUS[:pass], 'Service responded with bundle.', @bundle.raw_xml)
      end

      #
      # Test if we can create a new resource and post it to the server.
      #
      def create_test
        result = TestResult.new('X010',"Create new #{resource_class.name.demodulize}", nil, nil, nil)
        @temp_resource = ResourceGenerator.generate(@resource_class,true)
        reply = @client.create @temp_resource
        @temp_id = reply.id
        @temp_version = reply.version

        if reply.code==201
          result.update(STATUS[:pass], "New #{resource_class.name.demodulize} was created.", reply.body)
        else
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          result.update(STATUS[:fail], message, reply.body)
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
          @preexisting_id = @bundle.get(1).resource_id
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
        else
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        reply = @client.read(@resource_class, @preexisting_id)
        @preexisting = reply.resource

        if @preexisting.nil?
          return result.update(STATUS[:fail], "Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id}", reply.body)
        end

        @preexisting_version = reply.version

        result.update(STATUS[:pass], "Successfully read preexisting #{resource_class.name.demodulize}.", @preexisting.to_xml)
      end

      #
      # Test if we can update a preexisting resource.
      #
      def update_test
        result = TestResult.new('X030',"Update existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@bundle.nil? and @bundle.size>0
          @preexisting_id = @bundle.get(1).resource_id
          @preexisting = @bundle.get(1).resource    
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
          @preexisting = @temp_resource
        else
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        if @preexisting.nil?
          result.update(STATUS[:fail], "Unable to update -- no existing #{resource_class.name.demodulize} is available or could be created.", nil)
        else
          ResourceGenerator.set_fields!(@preexisting)

          reply = @client.update @preexisting, @preexisting_id

          if reply.code==200
            result.update(STATUS[:pass], "Updated existing #{resource_class.name.demodulize}.", reply.body)
          elsif reply.code==201
            # check created id -- see if it matches the one we used, or is new
            resulting_id = reply.id

            if(@preexisting_id != resulting_id)
              # binding.pry
              result.update(STATUS[:fail], "Server created (201) new #{resource_class.name.demodulize} rather than update (200). A new ID (#{resulting_id}) was also created (was #{@preexisting_id}).", reply.body)
            else
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server responded with the wrong code (201, but should have been 200).", reply.body)
            end

            resulting_version = reply.version
            if(@preexisting_version == resulting_version)
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server did not update the resource version number.", reply.body)
            end
          else
            outcome = self.parse_operation_outcome(reply.body)
            message = self.build_messages(outcome)
            result.update(STATUS[:fail], message, reply.body)
          end
        end

        result
      end

      #
      # Test if we can retrieve the history of a preexisting resource.
      #
      def history_test
        result = TestResult.new('X040',"Read history of existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if @preexisting_id.nil?
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        reply = @client.resource_instance_history(@resource_class, @preexisting_id)
        @history_bundle = reply.resource
        if @history_bundle.nil?
          return result.update(STATUS[:fail], 'Service did not respond with bundle.', nil)
        end

        result.update(STATUS[:pass], 'Service responded with bundle.', @history_bundle.raw_xml)
      end

      #
      # Test if we can read a specific version of a preexisting resource.
      #
      def vread_current_test
        result = TestResult.new('X050',"Version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@history_bundle.nil? and @history_bundle.size>0
          @preexisting_id = @history_bundle.get(0).resource_id
          @preexisting_version = @history_bundle.get(0).resource_version
          @preexisting = @history_bundle.get(0).resource    
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
          @preexisting_version = @temp_version
          @preexisting = @temp_resource
        else
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        reply = @client.vread(@resource_class, @preexisting_id, @preexisting_version)

        if reply.resource.nil?
          return result.update(STATUS[:fail], "Server failed to return preexisting #{resource_class.name.demodulize}.", reply.body)
        elsif reply.code != 200
          return result.update(STATUS[:fail], "Server returned preexisting #{resource_class.name.demodulize}, but responded with HTTP#{reply.code}.", nil)
        elsif (reply.id != @preexisting_id) and (reply.version != @preexisting_version)
          return result.update(STATUS[:fail], "Server did not respond with correct information in the content-location header.", nil)
        end

        result.update(STATUS[:pass], "Read current version of preexisting #{resource_class.name.demodulize}.", reply.body)
      end

      #
      # Test if we can read a specific version of a preexisting resource.
      #
      def vread_previous_test
        result = TestResult.new('X055',"Previous version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@history_bundle.nil? and @history_bundle.size>1
          @preexisting_id = @history_bundle.get(1).resource_id
          @preexisting_version = @history_bundle.get(1).resource_version
          @preexisting = @history_bundle.get(1).resource    
        else
          return result.update(STATUS[:fail], "Previous version of #{resource_class.name.demodulize} unavailable.", nil)
        end

        reply = @client.vread(@resource_class, @preexisting_id, @preexisting_version)

        if reply.resource.nil?
          return result.update(STATUS[:fail], "Server failed to return preexisting #{resource_class.name.demodulize}.", reply.body)
        elsif reply.code != 200
          return result.update(STATUS[:fail], "Server returned preexisting #{resource_class.name.demodulize}, but responded with HTTP#{reply.code}.", nil)
        elsif (reply.id != @preexisting_id) and (reply.version != @preexisting_version)
          return result.update(STATUS[:fail], "Server did not respond with correct information in the content-location header.", nil)
        end
 
        result.update(STATUS[:pass], "Read previous version of preexisting #{resource_class.name.demodulize}.", reply.body)
      end


      #
      # Validate the representation of a given resource.
      #
      def validate_test
        result = TestResult.new('X060',"Validate #{resource_class.name.demodulize}", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,true)
        reply = @client.validate @temp_resource

        if reply.code==200
          result.update(STATUS[:pass], "#{resource_class.name.demodulize} was validated.", reply.body)
        elsif reply.code==201
          result.update(STATUS[:fail], "Server created a #{resource_class.name.demodulize} with the ID `_validate` rather than validate the resource.", reply.body)
        else
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          result.update(STATUS[:fail], message, reply.body)
        end

        result
      end

      #
      # Validate the representation of an existing resource.
      #
      def validate_existing_test
        result = TestResult.new('X065',"Validate existing #{resource_class.name.demodulize}", nil, nil, nil)

        if !@bundle.nil? and @bundle.size>0
          @preexisting_id = @bundle.get(1).resource_id
          @preexisting = @bundle.get(1).resource    
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
          @preexisting = @temp_resource
        else
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        if @preexisting.nil?
          result.update(STATUS[:fail], "Unable to validate -- no existing #{resource_class.name.demodulize} is available to be validated.", nil)
        else
          ResourceGenerator.set_fields!(@preexisting)

          reply = @client.validate_existing(@preexisting, @preexisting_id)

          if reply.code==200
            result.update(STATUS[:pass], "Existing #{resource_class.name.demodulize} was validated.", reply.body)
          elsif reply.code==201
            result.update(STATUS[:fail], "Server created a #{resource_class.name.demodulize} with the ID `_validate` rather than validate the resource.", reply.body)
          else
            outcome = self.parse_operation_outcome(reply.body)
            message = self.build_messages(outcome)
            result.update(STATUS[:fail], message, reply.body)
          end
        end

        result
      end

      #
      # Validate the representation of a resource against a given profile.
      #
      # The client can ask the server to validate against a particular resource by attaching a profile tag to the resource. 
      # This is an assertion that the resource conforms to the specified profile(s), and the server can check this.
      #
      test 'X067', 'Validate against a profile' do
        skip
      end

      #
      # Test if we can delete a preexisting resource.
      #
      # 204 == deleted
      # 405 == not allowed
      # 404 == not found
      # 409 == conflict, cannot be deleted (e.g. referential integrity won't allow it)
      #
      def delete_existing_test
        result = TestResult.new('X070',"Delete existing #{resource_class.name.demodulize}", nil, nil, nil)

        if !@bundle.nil? and @bundle.size>0
          @preexisting_id = @bundle.get(1).resource_id
          @preexisting = @bundle.get(1).resource    
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
          @preexisting = @temp_resource
        else
          return result.update(STATUS[:fail], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        reply = @client.destroy(@resource_class,@preexisting_id)

        if reply.code==204
          result.update(STATUS[:pass], "Existing #{resource_class.name.demodulize} was deleted.", reply.body)
        elsif reply.code==405
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          message.unshift "Server does not allow deletion of #{resource_class.name.demodulize}"
          result.update(STATUS[:fail], message, reply.body)
        elsif reply.code==404
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          message.unshift "Server was unable to find (404 not found) the #{resource_class.name.demodulize} with the ID `#{preexisting_id}`"
          result.update(STATUS[:fail], message, reply.body)
        elsif reply.code==409
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          message.unshift "Server had a conflict try to delete the #{resource_class.name.demodulize} with the ID `#{preexisting_id}"
          result.update(STATUS[:fail], message, reply.body)
        else
          outcome = self.parse_operation_outcome(reply.body)
          message = self.build_messages(outcome)
          result.update(STATUS[:fail], message, reply.body)
        end
   
        result
      end

    end
  end
end
