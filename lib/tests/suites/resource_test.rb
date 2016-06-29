module Crucible
  module Tests
    class ResourceTest < BaseSuite

      attr_accessor :resource_class
      attr_accessor :bundle
      attr_accessor :history_bundle

      attr_accessor :temp_resource
      attr_accessor :temp_version

      attr_accessor :conditional_create_resource_a
      attr_accessor :conditional_create_resource_b
      attr_accessor :conditional_create_resource_c
      attr_accessor :conditional_update_resource_a
      attr_accessor :conditional_update_resource_c

      attr_accessor :preexisting_id
      attr_accessor :preexisting_version
      attr_accessor :preexisting

      def execute(resource_class=nil)
        if resource_class
          @resource_class = resource_class
          {"ResourceTest_#{@resource_class.name.demodulize}" => execute_test_methods}
        else
          results = {}
          Crucible::Tests::BaseSuite.fhir_resources.each do | klass |
            @resource_class = klass
            results.merge!({"ResourceTest_#{@resource_class.name.demodulize}" => execute_test_methods})
          end
          results
        end
      end

      def id
        suffix = resource_class
        suffix = resource_class.name.demodulize if !resource_class.nil?
        "ResourceTest_#{suffix}"
      end

      def description
        "Basic operations for FHIR #{resource_class.name.demodulize} resource (CREATE, READ, VREAD, UPDATE, DELETE, HISTORY, SEARCH, VALIDATE)"
      end

      def category
        resource = @resource_class.nil? ? "Uncategorized" : resource_category(@resource_class.name.demodulize)
        {id: "resources_#{resource.parameterize}", title: "#{resource} Resources"}
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
      end

      # this allows results to have unique ids for resource based tests
      def result_id_suffix
        resource_class.name.demodulize
      end

      def supplement_test_description(desc)
        "#{resource_class.name.demodulize}: #{desc}"
      end

      def teardown
        @conditional_create_resource_a.destroy if @conditional_create_resource_a
        @conditional_create_resource_b.destroy if @conditional_create_resource_b
        @conditional_create_resource_c.destroy if @conditional_create_resource_c
        @conditional_create_resource_d.destroy if @conditional_create_resource_d
      end

      #
      # Get and read all the resources of this type. Result is an XML ATOM bundle.
      #
      test 'X000', 'Read Type' do
        metadata {
          define_metadata('read')
        }

        @bundle = resource_class.search
        assert_bundle_response @client.reply
        assert !@bundle.nil?, 'Service did not respond with bundle.'
      end

      #
      # Test if we can create a new resource and post it to the server.
      #
      test 'X010', 'Create New' do
        metadata {
          define_metadata('create')
        }

        result = TestResult.new('X010',"Create new #{resource_class.name.demodulize}", nil, nil, nil)
        ignore_client_exception { @temp_resource = ResourceGenerator.generate(@resource_class,3).create }
        @temp_version = @client.reply.version

        if @client.reply.code==201
          result.update(STATUS[:pass], "New #{resource_class.name.demodulize} was created.", @client.reply.body)
        else
          outcome = (self.parse_operation_outcome(@client.reply.body) rescue nil)
          if outcome.nil?
            message = "Response code #{@client.reply.code} with no OperationOutcome provided."
          else
            message = self.build_messages(outcome)
          end
          result.update(STATUS[:fail], message, @client.reply.body)
        end

        result
      end

      test 'X012', 'Conditional Create (No Matches)' do
        metadata {
          define_metadata('conditional-create')
        }

        result = TestResult.new('X012',"Conditional Create #{resource_class.name.demodulize} (No Matches)", nil, nil, nil)
        # chances are good that no resource has this ID
        ifNoneExist = { '_id' => "#{(SecureRandom.uuid * 2)[0..63]}" }
        ignore_client_exception { @conditional_create_resource_a = ResourceGenerator.generate(@resource_class,3).conditional_create(ifNoneExist) }

        if @client.reply.code==201
          result.update(STATUS[:pass], "New #{resource_class.name.demodulize} was created.", @client.reply.body)
        else
          outcome = (self.parse_operation_outcome(@client.reply.body) rescue nil)
          if outcome.nil?
            message = "Response code #{@client.reply.code} with no OperationOutcome provided."
          else
            message = self.build_messages(outcome)
          end
          result.update(STATUS[:fail], message, @client.reply.body)
        end

        result
      end


      test 'X013', 'Conditional Create (One Match)' do
        metadata {
          define_metadata('conditional-create')
        }

        result = TestResult.new('X013',"Conditional Create #{resource_class.name.demodulize} (One Match)", nil, nil, nil)
        # this ID should already exist if temp resource was created
        if !@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end
        ifNoneExist = { '_id' => @preexisting_id }
        ignore_client_exception { @conditional_create_resource_b = ResourceGenerator.generate(@resource_class,3).conditional_create(ifNoneExist) }

        @temp_version = @client.reply.version

        if @client.reply.code==200
          result.update(STATUS[:pass], "Request was correctly ignored.", @client.reply.body)
          @conditional_create_resource_b = nil
        else
          result.update(STATUS[:fail], "Request should have been ignored with HTTP 200.", @client.reply.body)
        end

        result
      end


      test 'X014', 'Conditional Create (Multiple Matches)' do
        metadata {
          define_metadata('conditional-create')
        }

        result = TestResult.new('X014',"Conditional Create #{resource_class.name.demodulize}", nil, nil, nil)
        # this should match all resources
        ifNoneExist = { '_lastUpdated' => 'gt1900-01-01' }
        ignore_client_exception { @conditional_create_resource_c = ResourceGenerator.generate(@resource_class,3).conditional_create(ifNoneExist) }
        @temp_version = @client.reply.version

        if @client.reply.code==412
          result.update(STATUS[:pass], "Request correctly failed.", @client.reply.body)
        else
          result.update(STATUS[:fail], "Request should have failed with HTTP 412.", @client.reply.body)
        end

        result
      end      

      #
      # Test if we can read a preexisting resource
      #
      test 'X020', 'Read Existing' do
        metadata {
          define_metadata('read')
        }

        result = TestResult.new('X020',"Read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)
        if !@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} unknown.", nil)
        end

        ignore_client_exception { @preexisting = @resource_class.read(@preexisting_id) }

        if @preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id}", @client.reply.body)
        else
          begin
            @preexisting.to_xml
          rescue Exception
            @preexisting = nil
            raise AssertionException.new("Read preexisting #{resource_class.name.demodulize}, but it appears invalid.", @client.reply.response)
          end
        end

        @preexisting_version = @client.reply.version

        result.update(STATUS[:pass], "Successfully read preexisting #{resource_class.name.demodulize}.", @client.reply.response)
        result
      end

      #
      # Test if we can update a preexisting resource.
      #
      test 'X030', 'Update Existing' do
        metadata {
          define_metadata('update')
        }

        result = TestResult.new('X030',"Update existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting = @temp_resource
        elsif !@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
          @preexisting = @bundle.entry[0].resource
        end

        if !@preexisting.nil?
          begin
            @preexisting.to_xml
          rescue Exception
            @preexisting = nil
          end
        end

        if @preexisting.nil?
          result.update(STATUS[:skip], "Unable to update -- existing #{resource_class.name.demodulize} is not available or was not valid.", nil)
        else
          ResourceGenerator.set_fields!(@preexisting)
          ResourceGenerator.apply_invariants!(@preexisting)

          ignore_client_exception { @preexisting.update }

          if @client.reply.code==200
            result.update(STATUS[:pass], "Updated existing #{resource_class.name.demodulize}.", @client.reply.body)
          elsif @client.reply.code==201
            # check created id -- see if it matches the one we used, or is new
            resulting_id = @client.reply.id

            if(@preexisting_id != resulting_id)
              result.update(STATUS[:fail], "Server created (201) new #{resource_class.name.demodulize} rather than update (200). A new ID (#{resulting_id}) was also created (was #{@preexisting_id}).", @client.reply.body)
            else
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server responded with the wrong code (201, but should have been 200).", @client.reply.body)
            end

            resulting_version = @client.reply.version
            if(@preexisting_version == resulting_version)
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server did not update the resource version number.", @client.reply.body)
            end
          else
            outcome = self.parse_operation_outcome(@client.reply.body) rescue nil
            if outcome.nil?
              message = "Response code #{@client.reply.code} with no OperationOutcome provided."
            else
              message = self.build_messages(outcome)
            end
            result.update(STATUS[:fail], message, @client.reply.body)
          end
        end

        result
      end

      test 'X032', 'Conditional Update (No Matches)' do
        metadata {
          define_metadata('conditional-update')
        }

        result = TestResult.new('X032',"Conditional Update #{resource_class.name.demodulize} (No Matches)", nil, nil, nil)

        searchParams = { '_id' => "#{(SecureRandom.uuid * 2)[0..63]}" }
        ignore_client_exception { @conditional_update_resource_a = ResourceGenerator.generate(@resource_class,3).conditional_update(searchParams) } 
        # chances are good that no resource has this ID

        if @client.reply.code==201
          result.update(STATUS[:pass], "New #{resource_class.name.demodulize} was created.", @client.reply.body)
        else
          outcome = (self.parse_operation_outcome(@client.reply.body) rescue nil)
          if outcome.nil?
            message = "Response code #{@client.reply.code} with no OperationOutcome provided."
          else
            message = self.build_messages(outcome)
          end
          result.update(STATUS[:fail], message, @client.reply.body)
        end

        result
      end


      test 'X033', 'Conditional Update (One Match)' do
        metadata {
          define_metadata('conditional-update')
        }

        result = TestResult.new('X033',"Conditional Update #{resource_class.name.demodulize} (One Match)", nil, nil, nil)
        if !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting = @temp_resource
        elsif !@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
          @preexisting = @bundle.entry[0].resource
        end

        if !@preexisting.nil?
          begin
            @preexisting.to_xml
          rescue Exception
            @preexisting = nil
          end
        end

        if @preexisting.nil?
          result.update(STATUS[:skip], "Unable to update -- existing #{resource_class.name.demodulize} is not available or was not valid.", nil)
        else
          ResourceGenerator.set_fields!(@preexisting)
          ResourceGenerator.apply_invariants!(@preexisting)
          
          searchParams = { '_id' => @preexisting_id }
          ignore_client_exception { @preexisting.conditional_update(searchParams) } 

          if @client.reply.code==200
            result.update(STATUS[:pass], "Updated existing #{resource_class.name.demodulize}.", @client.reply.body)
          elsif @client.reply.code==201
            # check created id -- see if it matches the one we used, or is new
            resulting_id = @client.reply.id

            if(@preexisting_id != resulting_id)
              result.update(STATUS[:fail], "Server created (201) new #{resource_class.name.demodulize} rather than update (200). A new ID (#{resulting_id}) was also created (was #{@preexisting_id}).", @client.reply.body)
            else
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server responded with the wrong code (201, but should have been 200).", @client.reply.body)
            end

            resulting_version = @client.reply.version
            if(@preexisting_version == resulting_version)
              result.update(STATUS[:fail], "The #{resource_class.name.demodulize} was successfully updated, but the server did not update the resource version number.", @client.reply.body)
            end
          else
            outcome = self.parse_operation_outcome(@client.reply.body) rescue nil
            if outcome.nil?
              message = "Response code #{@client.reply.code} with no OperationOutcome provided."
            else
              message = self.build_messages(outcome)
            end
            result.update(STATUS[:fail], message, @client.reply.body)
          end
        end

        result
      end


      test 'X034', 'Conditional Update (Multiple Matches)' do
        metadata {
          define_metadata('conditional-update')
        }

        result = TestResult.new('X034',"Conditional Update #{resource_class.name.demodulize}", nil, nil, nil)
        searchParams = { '_lastUpdated' => 'gt1900-01-01' }
        ignore_client_exception { @conditional_update_resource_c = ResourceGenerator.generate(@resource_class,3).conditional_update(searchParams) }
        # this should match all resources
        @temp_version = @client.reply.version

        if @client.reply.code==412
          result.update(STATUS[:pass], "Request correctly failed.", @client.reply.body)
          @conditional_update_resource_c = nil
        else
          result.update(STATUS[:fail], "Request should have failed with HTTP 412.", @client.reply.body)
        end
        result
      end   

      #
      # Test if we can retrieve the history of a preexisting resource.
      #
      test 'X040', 'Read History of existing' do
        metadata {
          define_metadata('history')
        }

        result = TestResult.new('X040',"Read history of existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if @preexisting_id.nil?
          result.update(STATUS[:skip], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        else
          @history_bundle = @resource_class.resource_instance_history(@preexisting_id)
          if @history_bundle.nil?
            raise AssertionException.new('Service did not respond with bundle.', nil)
          end
          result.update(STATUS[:pass], 'Service responded with bundle.', @client.reply.body)
        end
        result
      end

      #
      # Test if we can read a specific version of a preexisting resource.
      #
      test 'X050', 'Version read existing' do
        metadata {
          define_metadata('vread')
        }

        result = TestResult.new('X050',"Version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@history_bundle.nil? && @history_bundle.total && @history_bundle.total>0 && @history_bundle.entry && !@history_bundle.entry[0].nil? && !@history_bundle.entry[0].resource.nil?
          @preexisting = @history_bundle.entry[0].resource
          @preexisting_id = @preexisting.id
          @preexisting_version = nil
          @preexisting_version = @preexisting.meta.versionId if !@preexisting.meta.nil?
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting_version = @temp_version
          @preexisting = @temp_resource
        end

        if @preexisting.nil?
          result.update(STATUS[:skip], "Preexisting #{resource_class.name.demodulize} unknown.", nil)
        else
          vread_resource = nil
          ignore_client_exception { vread_resource = @resource_class.vread(@preexisting_id, @preexisting_version) }
          if vread_resource.nil?
            raise AssertionException.new("Server failed to return preexisting #{resource_class.name.demodulize}.", @client.reply.body)
          elsif @client.reply.code != 200
            raise AssertionException.new("Server returned preexisting #{resource_class.name.demodulize}, but responded with HTTP#{@client.reply.code}.", nil)
          elsif (@client.reply.id != @preexisting_id) and (@client.reply.version != @preexisting_version)
            raise AssertionException.new("Server did not respond with correct information in the content-location header.", nil)
          end
          result.update(STATUS[:pass], "Read current version of preexisting #{resource_class.name.demodulize}.", @client.reply.body)
        end
        result
      end

      #
      # Test if we can read a specific version of a preexisting resource.
      #
      test 'X055', 'Previous version read existing' do
        metadata {
          define_metadata('vread')
        }

        result = TestResult.new('X055',"Previous version read existing #{resource_class.name.demodulize} by ID", nil, nil, nil)

        if !@history_bundle.nil? && @history_bundle.total && @history_bundle.total>0 && @history_bundle.entry && !@history_bundle.entry[0].nil? && !@history_bundle.entry[0].resource.nil?
          @preexisting = @history_bundle.entry[0].resource
          @preexisting_id = @preexisting.id
          @preexisting_version = nil
          @preexisting_version = @preexisting.meta.versionId if !@preexisting.meta.nil?
        end

        if @preexisting.nil?
          result.update(STATUS[:skip],"Previous version of #{resource_class.name.demodulize} unavailable.", nil)
        else
          vread_resource = nil
          ignore_client_exception { vread_resource = @resource_class.vread(@preexisting_id, @preexisting_version) }
          if vread_resource.nil?
            raise AssertionException.new("Server failed to return preexisting #{resource_class.name.demodulize}.", @client.reply.body)
          elsif @client.reply.code != 200
            raise AssertionException.new("Server returned preexisting #{resource_class.name.demodulize}, but responded with HTTP#{@client.reply.code}.", nil)
          elsif (@client.reply.id != @preexisting_id) and (@client.reply.version != @preexisting_version)
            raise AssertionException.new("Server did not respond with correct information in the content-location header.", nil)
          end
          result.update(STATUS[:pass], "Read previous version of preexisting #{resource_class.name.demodulize}.", @client.reply.body)
        end
        result
      end


      #
      # Validate the representation of a given resource.
      #
      # Interestingly, this functionality is deprecated in the latest "Continuous Integration" branch.
      #
      test 'X060', 'Validate' do
        metadata {
          define_metadata('$validate')
          validates profiles: ['validate-profile']
        }

        result = TestResult.new('X060',"Validate #{resource_class.name.demodulize}", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)
        reply = @client.validate @temp_resource
        if reply.code==200
          result.update(STATUS[:pass], "#{resource_class.name.demodulize} was validated.", reply.body)
        elsif reply.code==201
          result.update(STATUS[:fail], "Server created a #{resource_class.name.demodulize} with the ID `_validate` rather than validate the resource.", reply.body)
        else
          outcome = self.parse_operation_outcome(reply.body) rescue nil
          if outcome.nil?
            message = "Response code #{reply.code} with no OperationOutcome provided."
          else
            message = self.build_messages(outcome)
          end
          result.update(STATUS[:fail], message, reply.body)
        end

        result
      end

      #
      # Validate the representation of an existing resource.
      #
      # Interestingly, this functionality is deprecated in the latest "Continuous Integration" branch.
      #
      test 'X065', 'Validate Existing' do
        metadata {
          define_metadata('$validate')
          validates profiles: ['validate-profile']
        }

        result = TestResult.new('X065',"Validate existing #{resource_class.name.demodulize}", nil, nil, nil)

        if !@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
          @preexisting = @bundle.entry[0].resource
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting = @temp_resource
        end

        if !@preexisting.nil?
          begin
            @preexisting.to_xml
          rescue Exception
            @preexisting = nil
          end
        end

        if @preexisting.nil?
          result.update(STATUS[:skip], "Unable to validate -- existing #{resource_class.name.demodulize} is not available or was not valid.", nil)
        else
          # ResourceGenerator.set_fields!(@preexisting)
          # ResourceGenerator.apply_invariants!(@preexisting)

          reply = @client.validate_existing(@preexisting, @preexisting_id)

          if reply.code==200
            result.update(STATUS[:pass], "Existing #{resource_class.name.demodulize} was validated.", reply.body)
          elsif reply.code==201
            result.update(STATUS[:fail], "Server created a #{resource_class.name.demodulize} with the ID `_validate` rather than validate the resource.", reply.body)
          elsif reply.code==400
            outcome = self.parse_operation_outcome(reply.body) rescue nil

            if outcome.nil?
              message = "Response code #{reply.code} with no OperationOutcome provided."
              result.update(STATUS[:fail], message, reply.body)
            else
              message = self.build_messages(outcome)
              invalid_codes = ['invalid','structure','required','value','invariant']
              security_codes = ['security','login','unknown','expired','forbidden','suppressed']
              processing_codes = ['processing','not-supported','duplicate','not-found','too-long','code-invalid','extension','too-costly','business-rule','conflict','incomplete']
              transient_codes = ['transient','lock-error','no-store','exception','timeout','throttled']
            
              status = :pass
              outcome.issue.each do |issue|
                if ['fatal','error'].include?(issue.severity)
                  status = :fail if security_codes.include?(issue.code) || transient_codes.include?(issue.code)
                end
              end
              result.update(STATUS[status], message, reply.body)
            end
          else
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            if outcome.nil?
              message = "Response code #{reply.code} with no OperationOutcome provided."
            else
              message = self.build_messages(outcome)
            end
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
      # Profile Tag has an HTTP header named "Category" with three parts:
      #   scheme: [uri]    "http://hl7.org/fhir/tag/profile"
      #   term:   [uri]    In a profile tag, the term is a URL that references a profile resource.
      #   label:  [string] (optional) A human-readable label for the tag for use when displaying in end-user applications
      #
      # Category: [Tag Term]; scheme="[Tag Scheme]"; label="[Tag label]"(, ...)
      #
      # Interestingly, this functionality is deprecated in the latest "Continuous Integration" branch.
      #
      test 'X067', 'Validate against a profile' do
        metadata {
          define_metadata('$validate')
          validates profiles: ['validate-profile']
        }

        profile_uri = "http://hl7.org/fhir/StructureDefinition/#{resource_class.name.demodulize}" # the profile to validate with

        result = TestResult.new('X067',"Validate #{resource_class.name.demodulize} against a profile", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)
        reply = @client.validate(@temp_resource,{profile_uri: profile_uri})
        if reply.code==200
          result.update(STATUS[:pass], "#{resource_class.name.demodulize} was validated.", reply.body)
        elsif reply.code==201
          result.update(STATUS[:fail], "Server created a #{resource_class.name.demodulize} with the ID `_validate` rather than validate the resource.", reply.body)
        else
          outcome = self.parse_operation_outcome(reply.body) rescue nil
          if outcome.nil?
            message = "Response code #{reply.code} with no OperationOutcome provided."
          else
            message = self.build_messages(outcome)
          end
          result.update(STATUS[:fail], message, reply.body)
        end

        result
      end

      #
      # Test if we can delete a preexisting resource.
      #
      # 204 == deleted
      # 405 == not allowed
      # 404 == not found
      # 409 == conflict, cannot be deleted (e.g. referential integrity won't allow it)
      #
      test 'X070', 'Delete Existing' do
        metadata {
          define_metadata('delete')
        }

        @x070_success = false
        result = TestResult.new('X070',"Delete existing #{resource_class.name.demodulize}", nil, nil, nil)

        if !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting = @temp_resource
        end
        if @preexisting_id.nil? &&!@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
          @preexisting = @bundle.entry[0].resource
        end

        if @preexisting_id.nil?
          result.update(STATUS[:skip],"Preexisting #{resource_class.name.demodulize} unknown.", nil)
        else
          reply = @client.destroy(@resource_class,@preexisting_id)
          if reply.code==204
            @x070_success = true
            result.update(STATUS[:pass], "Existing #{resource_class.name.demodulize} was deleted.", reply.body)
          elsif reply.code==405
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            message = self.build_messages(outcome)
            message.unshift "Server does not allow deletion of #{resource_class.name.demodulize}"
            result.update(STATUS[:fail], message, reply.body)
          elsif reply.code==404
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            message = self.build_messages(outcome)
            message.unshift "Server was unable to find (404 not found) the #{resource_class.name.demodulize} with the ID `#{preexisting_id}`"
            result.update(STATUS[:fail], message, reply.body)
          elsif reply.code==409
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            message = self.build_messages(outcome)
            message.unshift "Server had a conflict try to delete the #{resource_class.name.demodulize} with the ID `#{preexisting_id}"
            result.update(STATUS[:fail], message, reply.body)
          else
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            message = self.build_messages(outcome)
            result.update(STATUS[:fail], message, reply.body)
          end
        end

        result
      end

      test 'X075', 'Get Deleted Resource' do
        metadata {
          define_metadata('delete')
        }
        skip unless @x070_success

        result = TestResult.new('X075',"Get Deleted #{resource_class.name.demodulize}", nil, nil, nil)

        if !@temp_resource.nil?
          @preexisting_id = @temp_resource.id
          @preexisting = @temp_resource
        end
        if @preexisting_id.nil? &&!@bundle.nil? && @bundle.total && @bundle.total>0 && @bundle.entry && !@bundle.entry[0].nil? && !@bundle.entry[0].resource.nil?
          @preexisting_id = @bundle.entry[0].resource.id
          @preexisting = @bundle.entry[0].resource
        end

        if @preexisting_id.nil?
          result.update(STATUS[:skip],"Preexisting #{resource_class.name.demodulize} unknown.", nil)
        else
          reply = @client.read(@resource_class,@preexisting_id)
          if reply.code==410
            result.update(STATUS[:pass], "Deleted #{resource_class.name.demodulize} was correctly reported as gone.", reply.body)
          elsif reply.code==404
            message = "Deleted #{resource_class.name.demodulize} was reported as unknown (404). If the system tracks deleted resources, it should respond with 410."
            result.update(STATUS[:pass], message , reply.body)
            result.warnings = [ message ]
          else
            outcome = self.parse_operation_outcome(reply.body) rescue nil
            message = self.build_messages(outcome)
            result.update(STATUS[:fail], message, reply.body)
          end
        end

        result
      end

      def define_metadata(method)
        links "#{REST_SPEC_LINK}##{method}"
        links "#{BASE_SPEC_LINK}/#{resource_class.name.demodulize.downcase}.html"
        validates resource: resource_class.name.demodulize, methods: [method]
      end

    end
  end
end
