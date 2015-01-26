
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

        # use for resource comparision later
        client1_reply = @client.read(@resource_class, @preexisting_id)

        # make sure the resource was read
        assert_response_ok client1_reply, "Unable to read resource from service 1."

        @preexisting = client1_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 1", client1_reply.body)
        end

        # create on client 2
        # this might fail if you dont drop the id
        client2_reply = @client2.create @preexisting

        assert_response_ok client2_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        client2_resource_read = client2.read(client2_reply.id)

        assert_response_ok client2_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        assert client2_resource_read.resource.equals?(@preexisting), "Found differences:"
      end

      test 'RT01a','Transfer existing resource from client 1 to client 2 - without id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT01a',"Read #{resource_class.name.demodulize} from client 1 and create on client 2 - without id", nil, nil, nil)

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

        # use for resource comparision later
        client1_reply = @client.read(@resource_class, @preexisting_id)

        # make sure the resource was read
        assert_response_ok client1_reply, "Unable to read resource from service 1."

        @preexisting = client1_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 1", client1_reply.body)
        end

        @preexisting.id = nil 

        # create on client 2
        # this might fail if you dont drop the id
        client2_reply = @client2.create @preexisting

        assert_response_ok client2_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        client2_resource_read = client2.read(client2_reply.id)

        assert_response_ok client2_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        assert client2_resource_read.resource.equals?(@preexisting), "Found differences:"
      end

      test 'RT02','Transfer existing resource from client 2 to client 1' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT02',"Read #{resource_class.name.demodulize} from client 2 and create on client 1", nil, nil, nil)

        client2_resource_reply = @client.read_feed(@resource_class)
        @client2_bundle = client2_resource_reply.resource
        assert !@client2_bundle.nil?, 'Service 2 did not respond with bundle.'
        # ^ should I be using a bundle here to read an existing resource?

        if !@client2_bundle.nil? && @client2_bundle.total>0 && !@client2_bundle.entry[0].nil? && !@client2_bundle.entry[0].resource.nil?
          @preexisting_id = @client2_bundle.entry[0].resource.xmlId
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} on client 2 unknown.", nil)
        end

        # use for resource comparision later
        client2_reply = @client2.read(@resource_class, @preexisting_id)

        # make sure the resource was read
        assert_response_ok client2_reply, "Unable to read resource #{resource_class.name.demodulize} from service 2."

        @preexisting = client2_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 2", client2_reply.body)
        end

        # create on client 2
        # this might fail if you dont drop the id
        client1_reply = @client.create @preexisting

        assert_response_ok client1_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        client1_resource_read = client1.read(client1_reply.id)

        assert_response_ok client1_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        assert client1_resource_read.resource.equals?(@preexisting), "Found differences:"
      end

      test 'RT02a','Transfer existing resource from client 2 to client 1 - without id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT02',"Read #{resource_class.name.demodulize} from client 2 and create on client 1 - without id", nil, nil, nil)

        client2_resource_reply = @client.read_feed(@resource_class)
        @client2_bundle = client2_resource_reply.resource
        assert !@client2_bundle.nil?, 'Service 2 did not respond with bundle.'
        # ^ should I be using a bundle here to read an existing resource?

        if !@client2_bundle.nil? && @client2_bundle.total>0 && !@client2_bundle.entry[0].nil? && !@client2_bundle.entry[0].resource.nil?
          @preexisting_id = @client2_bundle.entry[0].resource.xmlId
        elsif !@temp_resource.nil?
          @preexisting_id = @temp_id
        else
          raise AssertionException.new("Preexisting #{resource_class.name.demodulize} on client 2 unknown.", nil)
        end

        # use for resource comparision later
        client2_reply = @client2.read(@resource_class, @preexisting_id)

        # make sure the resource was read
        assert_response_ok client2_reply, "Unable to read resource #{resource_class.name.demodulize} from service 2."

        @preexisting = client2_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 2", client2_reply.body)
        end

        @preexisting.id = nil 

        # create on client 2
        # this might fail if you dont drop the id
        client1_reply = @client.create @preexisting

        assert_response_ok client1_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        client1_resource_read = client1.read(client1_reply.id)

        assert_response_ok client1_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        assert client1_resource_read.resource.equals?(@preexisting), "Found differences:"
      end


      test 'RT03','Create resource on client 1 and transfer to client 2' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT03',"Create #{resource_class.name.demodulize} on client 1 and transfer to client 2", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)

        client1_reply = @client.create @temp_resource

        assert_response_ok client1_reply, "Unable to create resouruce #{resource_class.name.demodulize} on client 1"

        @temp_id = client1_reply.id
        @temp_version = client1_reply.version

        # use for resource comparision later
        client1_reply = @client.read(@resource_class, @temp_id)

        # make sure the resource was read
        assert_response_ok client1_reply, "Unable to read resource from service 1."

        @preexisting = client1_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 1", client1_reply.body)
        end

        # create on client 2
        # this might fail if you dont drop the id
        client2_reply = @client2.create @preexisting

        assert_response_ok client2_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        client2_resource_read = client2.read(client2_reply.id)

        assert_response_ok client2_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        assert client2_resource_read.resource.equals?(@preexisting), "Found differences:"
      end

      test 'RT03a','Create resource on client 1 and transfer to client 2 - without id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT03a',"Create #{resource_class.name.demodulize} on client 1 and transfer to client 2", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)

        client1_reply = @client.create @temp_resource

        assert_response_ok client1_reply, "Unable to create resouruce #{resource_class.name.demodulize} on client 1"

        @temp_id = client1_reply.id
        @temp_version = client1_reply.version

        # use for resource comparision later
        client1_reply = @client.read(@resource_class, @temp_id)

        # make sure the resource was read
        assert_response_ok client1_reply, "Unable to read resource from service 1."

        @preexisting = client1_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 1", client1_reply.body)
        end

        @preexisting.id = nil 

        # create on client 2
        # this might fail if you dont drop the id
        client2_reply = @client2.create @preexisting

        assert_response_ok client2_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        client2_resource_read = client2.read(client2_reply.id)

        assert_response_ok client2_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 2"

        assert client2_resource_read.resource.equals?(@preexisting), "Found differences:"
      end


      test 'RT04','Create resource on client 2 and transfer to client 1' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT04',"Create #{resource_class.name.demodulize} on client 2 and transfer to client 1", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)

        client2_reply = @client.create @temp_resource

        assert_response_ok client2_reply, "Unable to create resouruce #{resource_class.name.demodulize} on client 2"

        @temp_id = client2_reply.id
        @temp_version = client2_reply.version

        # use for resource comparision later
        client2_reply = @client2.read(@resource_class, @temp_id)

        # make sure the resource was read
        assert_response_ok client2_reply, "Unable to read resource from service 2."

        @preexisting = client2_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 2", client2_reply.body)
        end

        # create on client 2
        # this might fail if you dont drop the id
        client1_reply = @client.create @preexisting

        assert_response_ok client1_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        client1_resource_read = @client.read(client1_reply.id)

        assert_response_ok client1_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        assert client1_resource_read.resource.equals?(@preexisting), "Found differences:"
      end


      test 'RT04a','Create resource on client 2 and transfer to client 1 - without id' do
        metadata {
          links 'http://www.hl7.org/implement/standards/fhir/http.html#read'
          links 'http://www.hl7.org/implement/standards/fhir/http.html#create'
          requires resource: @resource_class, methods: ["create", "read"]
          validates resource: @resource_class, methods: ["create", "read"]
        }

        result = TestResult.new('RT04a',"Create #{resource_class.name.demodulize} on client 2 and transfer to client 1 - without id", nil, nil, nil)

        @temp_resource = ResourceGenerator.generate(@resource_class,3)

        client2_reply = @client.create @temp_resource

        assert_response_ok client2_reply, "Unable to create resouruce #{resource_class.name.demodulize} on client 2"

        @temp_id = client2_reply.id
        @temp_version = client2_reply.version

        # use for resource comparision later
        client2_reply = @client2.read(@resource_class, @temp_id)

        # make sure the resource was read
        assert_response_ok client2_reply, "Unable to read resource from service 2."

        @preexisting = client2_reply.resource

        if !@preexisting.nil?
          raise AssertionException.new("Failed to read preexisting #{resource_class.name.demodulize}: #{@preexisting_id} from client 2", client2_reply.body)
        end

        @preexisting.id = nil         

        # create on client 2
        # this might fail if you dont drop the id
        client1_reply = @client.create @preexisting

        assert_response_ok client1_reply, "Failed to create #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        client1_resource_read = @client.read(client1_reply.id)

        assert_response_ok client1_resource_read, "Failed to read #{resource_class.name.demodulize}: #{@preexisting_id} on client 1"

        assert client1_resource_read.resource.equals?(@preexisting), "Found differences:"
      end

    end
  end
end