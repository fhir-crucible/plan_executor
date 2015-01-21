
module Crucible
  module Tests
    class ResourceTransferTest < BaseTest

      attr_accessor :resource_class
      attr_accessor :client1_bundle
      attr_accessor :client2_bundle      


      attr_accessor :temp_resource
      attr_accessor :temp_id
      attr_accessor :temp_version

      attr_accessor :preexisting_id
      attr_accessor :preexisting_version
      attr_accessor :preexisting


      def id
        suffix = resource_class
        suffix = resource_class.name.demodulize if !resource_class.nil?
        "MultiServerResourceTest_#{suffix}"
      end

      def description
        "Test for basic transfer of FHIR #{resource_class.name.demodulize} resource across servers"
      end

      def multiserver
        true
      end

      def execute(resource_class=FHIR::Alert)
        if resource_class
          @resource_class = resource_class
          [{"ResourceTest_#{@resource_class.name.demodulize}" => {
            test_file: test_name,
            tests: execute_test_methods
          }}]
        else
          fhir_resources.map do | klass |
            @resource_class = klass
            {"ResourceTest_#{@resource_class.name.demodulize}" => {
              test_file: test_name,
              tests: execute_test_methods
            }}
          end
        end
      end



      test 'RT01','Transfer existing resource from client 1 to client 2' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT01',"Read #{resource_class.name.demodulize} from client 1 and create on client 2", nil, nil, nil)

        client1_resource_reply = @client.read_feed(@resource_class)
        @client1_bundle = client1_resource_reply.resource
        assert !@client1_bundle.nil?, 'Service 1 did not respond with bundle.'
        # ^ should I be using a bundle here to read an existing resource?

        if !@client1_bundle.nil? && @client1_bundle.total>0 && !@client1_bundle.entry[0].nil? && !@client1_bundle.entry[0].resource.nil?
          @preexisting_id = @client1_bundle.entry[0].resource.xmlId
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} on client 1 unknown.", nil)
        end

        client1_reply = @client.read(@resource_class, @preexisting_id)

        if !client1_reply.code==201
          raise AssertionException.new("Unable to read resource from service 2.")
        end

        @preexisting = client1_reply.resource

        if @preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 1", client1_reply.body)
        end

        # create on client 2
        client2_reply = @client2.create @preexisting
        if client2_reply.code==201
          result.update(STATUS[:pass], "Preexisting resource #{resource_class.name.demodulize} was read from client 1 and created on client 2", client2_reply.body)
        else
          outcome = self.parse_operation_outcome(client2_reply.body)
          message = self.build_messages(outcome)
          result.update(STATUS[:fail], message, client2_reply.body)
          @temp_resource = nil
        end
      end

      test 'RT02','Transfer existing resource from client 2 to client 1' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT01',"Read #{resource_class.name.demodulize} from client 1 and create on client 2", nil, nil, nil)

        client2_resource_reply = @client2.read_feed(@resource_class)
        @client2_bundle = client2_resource_reply.resource
        assert !@client2_bundle.nil?, 'Service 2 did not respond with bundle.'
        # ^ should I be using a bundle here to read an existing resource?

        if !@client2_bundle.nil? && @client2_bundle.total>0 && !@client2_bundle.entry[0].nil? && !@client2_bundle.entry[0].resource.nil?
          @preexisting_id = @client1_bundle.entry[0].resource.xmlId
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} on client 2 unknown.", nil)
        end

        client2_reply = @client2.read(@resource_class, @preexisting_id)

        if !client2_reply.code==201
          raise AssertionException.new("Unable to read resource from service 2.")
        end

        @preexisting = client2_reply.resource

        if @preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 2", client2_reply.body)
        end

        # create on client 2
        client1_reply = @client.create @preexisting
        if client1_reply.code==201
          result.update(STATUS[:pass], "Preexisting resource #{resource_class.name.demodulize} was read from client 2 and created on client 1", client1_reply.body)
        else
          outcome = self.parse_operation_outcome(client1_reply.body)
          message = self.build_messages(outcome)
          result.update(STATUS[:fail], message, client1_reply.body)
          @temp_resource = nil
        end
      end

    end
  end
end