module Crucible
  module Tests
    class BaseTestScript < BaseTest

      ASSERTION_MAP = {
        # equals	expected (value1 or xpath expression2) actual (value1 or xpath expression2)	Asserts that "expected" is equal to "actual".
        "equals" => :assert_equal,
        # response_code	code (numeric HTTP response code)	Asserts that the response code equals "code".
        "response_code" => :assert_response_code,
        # response_okay	N/A	Asserts that the response code is in the set (200, 201).
        "response_okay" => :assert_response_ok,
        # response_not_okay	N/A	Asserts that the response code is not in the set (200, 201).
        "response_not_okay" => :assert_response_not_ok,
        # response_created N/A Asserts that the response code is 201.
        "response_created" => :assert_response_created,
        # response_gone N/A Asserts that the response code is 410.
        "response_gone" => :assert_response_gone,
        # response_not_found	N/A	Asserts that the response code is 404.
        "response_not_found" => :assert_response_not_found,
        # response_bad	N/A	Asserts that the response code is 400.
        "response_bad" => :assert_response_bad,
        # navigation_links	Bundle	Asserts that the Bundle contains first, last, and next links.
        "navigation_links" => :assert_nagivation_links,
        # resource_type	resourceType (string)	Asserts that the response contained a FHIR Resource of the given "resourceType".
        "resource_type" => :assert_resource_type,
        # valid_content_type	N/A	Asserts that the response contains a "content-type" is either "application/xml+fhir" or "application/json+fhir" and that "charset" is specified as "UTF-8"
        "valid_content_type" => :assert_valid_resource_content_type_present,
        # valid_content_location	N/A	Asserts that the response contains a valid "content-location" header.
        "valid_content_location" => :assert_valid_content_location_present,
        # valid_last_modified N/A Asserts that the response contains a valid "last-modified" header.
        "valid_last_modified" => :assert_last_modified_present,
        # bundle_response N/A Asserts that the response is a bundle.
        "bundle_response" => :assert_bundle_response,
        # bundle_entry_count count (number of entries expected) Asserts that the number of entries matches expectations.
        "bundle_entry_count" => :assert_bundle_entry_count
      }

      def initialize(testscript, client, client2=nil)
        super(client, client2)
        @testscript = testscript
        define_tests
        load_fixtures
        @id_map = {}
      end

      def author
        @testscript.name
      end

      def description
        @testscript.description
      end

      def id
        @testscript.xmlId
      end

      def title
        id
      end

      def tests
        @testscript.test.map { |test| "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym }
      end

      def define_tests
        @testscript.test.each do |test|
          test_method = "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym
          define_singleton_method test_method, -> { process_test(test) }
        end
      end

      def load_fixtures
        @fixtures = {}
        @testscript.fixture.each do |fixture|
          if !fixture.uri.nil?
            @fixtures[fixture.xmlId] = Generator::Resources.new.load_fixture(fixture.uri)
          else
            @fixtures[fixture.xmlId] = fixture.resource
          end
        end
      end

      def process_test(test)
        result = TestResult.new(test.xmlId, test.name, STATUS[:pass], '','')
        @last_response = nil # clear out any responses from previous tests
        begin
          test.operation.each do |op|
            execute_operation op
          end
          # result.update(t.status, t.message, t.data) if !t.nil? && t.is_a?(Crucible::Tests::TestResult)
        rescue AssertionException => e
          result.update(STATUS[:fail], e.message, e.data)
        rescue => e
          result.update(STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
        end
        if !test.metadata.nil?
          result.requires = test.metadata.requires.map {|r| {resource: r.fhirType, methods: r.operations} } if !test.metadata.requires.empty?
          result.validates = test.metadata.validates.map {|r| {resource: r.fhirType, methods: r.operations} } if !test.metadata.requires.empty?
          result.links = test.metadata.link.map(&:url) if !test.metadata.link.empty?
        end
        result
      end

      def setup
        return if @testscript.setup.blank?
        @testscript.setup.operation.each do |op|
          execute_operation op
        end
      end

      def teardown
        return if @testscript.teardown.blank?
        @testscript.teardown.operation.each do |op|
          execute_operation op
        end
      end

      def execute_operation(operation)
        return if @client.nil?
        case operation.fhirType
        when 'create'
          @last_response = @client.create @fixtures[operation.source]
          @id_map[operation.source] = @last_response.id
        when 'update'
          target_id = @id_map[operation.target]
          fixture = @fixtures[operation.source]
          @last_response = @client.update fixture, target_id
        when 'read'
          if !operation.target.nil?
            @last_response = @client.read @fixtures[operation.target].class, @id_map[operation.target]
          else
            resource_type = operation.parameter.try(:first)
            resource_id = operation.parameter.try(:second)
            @last_response = @client.read "FHIR::#{resource_type}", resource_id
          end
        when 'delete'
          @client.destroy(FHIR::Condition, @cond1_reply.id) if !@cond1_id.nil?
          @last_response = @client.destroy @fixtures[operation.target].class, @id_map[operation.target]
          @id_map.delete(operation.target)
        when 'history'
          target_id = @id_map[operation.target]
          fixture = @fixtures[operation.target]
          @last_response = @client.resource_instance_history(fixture.class,target_id)
        when '$expand'
          @last_response = @client.value_set_expansion( extract_operation_parameters(operation) )
        when '$validate'
          @last_response = @client.value_set_code_validation( extract_operation_parameters(operation) )
        when 'assertion'
          handle_assertion(operation)
        else
          raise "Undefined operation for #{@testscript.name}-#{title}: #{operation.fhirType}"
        end
      end

      def handle_assertion(operation)
        assertion = operation.parameter.first
        if assertion.start_with? "resource_type"
          resource_type = "FHIR::#{assertion.split(":").last}".constantize
          assertion = assertion.split(":").first
        elsif assertion.start_with? "code"
          code = assertion.split(":").last
          assertion = assertion.split(":").first
        end
        if self.methods.include?(ASSERTION_MAP[assertion])
          method = self.method(ASSERTION_MAP[assertion])
          puts "ASSERTING: #{assertion}"
          case assertion
          when "code"
            method.call(@last_response, code)
          when "resource_type"
            method.call(@last_response, resource_type)
          when "response_code"
            code = operation.parameter[1]
            method.call(@last_response, code.to_i)
          when "equals"
            raise "'equals' assertion requires two parameters: [expected value, actual xpath]" unless operation.parameter.length >= 3
            expected, actual = handle_xpaths(operation)
            method.call(expected, actual)
          else
            params = operation.parameter[1..-1]
            method.call(@last_response, *params)
          end
        else
          raise "Undefined assertion for #{@testscript.name}-#{title}: #{operation.parameter}"
        end
      end

      def extract_operation_parameters(operation)
        options = {
          :id => @id_map[operation.target]
        }
        operation.parameter.each do |param|
          key, value = param.split("=")
          options[key.to_sym] = value
        end unless operation.parameter.blank?
        options
      end

      def handle_xpaths(operation)
        expected = operation.parameter[1]
        # some xpaths operate on OperationOutcome, which is in the response body
        resource_xml = @last_response.resource.try(:to_xml) || @last_response.body
        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
        element = resource_doc.xpath(operation.parameter[2])
        # for multiple possible values, just pick the first matching one...
        if element.length>1
          actual = ( element.detect { |e| actual = e.try(:value) if e.try(:value) == expected } ).try(:value)
        else
          actual = element.first.try(:value)
        end
        return expected, actual
      end

      #
      # def execute_test_method(test_method)
      #   test_item = @testscript.test.select {|t| "#{t.xmlId} #{t.name} test".downcase.tr(' ', '_').to_sym == test_method}.first
      #   result = Crucible::Tests::TestResult.new(test_item.xmlId, test_item.name, Crucible::Tests::BaseTest::STATUS[:skip], '','')
      #   # result.warnings = @warnings  unless @warnings.empty?
      #
      #   result.id = self.object_id.to_s
      #   result.code = test_item.to_xml
      #
      #   result.to_hash.merge!({:test_method => test_method})
      # end

    end
  end
end
