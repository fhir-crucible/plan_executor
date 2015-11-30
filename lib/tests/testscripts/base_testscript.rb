module Crucible
  module Tests
    class BaseTestScript < BaseTest
      
      CODE_MAP = {
        'okay' => 200,
        'created' => 201,
        'noContent' => 204,
        'notModified' => 304,
        'bad' => 400,
        'forbidden' => 403,
        'notFound' => 404,
        'methodNotAllowed' => 405,
        'conflict' => 409,
        'gone' => 410,
        'preconditionFailed' => 412,
        'unprocessable' => 422
      }

      OPERATOR_MAP = {
        'equals' => :equals,
        'notEquals' => :notEquals,
        'in' => :in,
        'notIn' => :notIn,
        'greaterThan' => :greaterThan,
        'lessThan' => :lessThan,
        'empty' => :empty,
        'notEmpty' => :notEmpty,
        'contains' => :contains,
        'notContains' => :notContains,
      }

      def initialize(testscript, client, client2=nil)
        super(client, client2)
        @id_map = {}
        @response_map = {}
        @warnings = []
        @autocreate = []
        @autodelete = []
        @testscript = testscript
        define_tests
        load_fixtures
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
        "TS-#{id}"
      end

      def tests
        @testscript.test.map { |test| "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym }
      end

      def debug_prefix
        "[TESTSCRIPT]:\t"
      end

      def log(message)
        puts "#{debug_prefix}#{message}"
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
          @fixtures[fixture.xmlId] = get_reference(fixture.resource.reference)
          @fixtures[fixture.xmlId].xmlId = nil unless @fixtures[fixture.xmlId].nil? #fixture resources cannot have an ID
          @autocreate << fixture.xmlId if fixture.autocreate
          @autodelete << fixture.xmlId if fixture.autodelete
        end
      end

      def collect_metadata(methods_only=false)
        @metadata_only = true
        result = execute
        result = result.values.first if methods_only
        @metadata_only = false
        result
      end

      def process_test(test)
        result = TestResult.new(test.xmlId, test.name, STATUS[:pass], '','')
        @last_response = nil # clear out any responses from previous tests
        begin
          test.action.each do |action|
            perform_action action
          end unless @setup_failed || @metadata_only
        rescue AssertionException => e
          result.update(STATUS[:fail], e.message, e.data)
        rescue => e
          result.update(STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
        end
        result.update(STATUS[:skip], "Skipped because setup failed.", "-") if @setup_failed
        result.warnings = @warnings unless @warnings.empty?
        unless test.metadata.nil?
          #todo add in requires and validates
          # result.requires = test.metadata.requires.map {|r| {resource: r.fhirType, methods: r.operations.try(:split, ', ')} } unless test.metadata.requires.empty?
          # result.validates = test.metadata.validates.map {|r| {resource: r.fhirType, methods: r.operations.try(:split, ', ')} } unless test.metadata.requires.empty?
          # result.links = test.metadata.link.map(&:url) if !test.metadata.link.empty?
          result.links = test.metadata.capability.map(&:link).flatten
        end
        result
      end

      def setup
        return if @testscript.setup.blank? && @autocreate.empty?
        @setup_failed = false
        begin
          @autocreate.each do |fixture_id|
            @last_response = @client.create @fixtures[fixture_id]
            @id_map[fixture_id] = @last_response.id
          end unless @client.nil?
          @testscript.setup.action.each do |action|
            perform_action action
          end unless @testscript.setup.blank?
        rescue AssertionException
          @setup_failed = true
        end
      end

      def teardown
        return if @testscript.teardown.blank? && @autodelete.empty?
        @testscript.teardown.action.each do |action|
          execute_operation action.operation unless action.operation.nil?
        end unless @testscript.teardown.blank?
        @autodelete.each do |fixture_id|
          @last_response = @client.destroy @fixtures[fixture_id].class, @id_map[fixture_id]
          @id_map.delete(fixture_id)
        end unless @client.nil?
      end

      def perform_action(action)
        execute_operation action.operation unless action.operation.nil?
        handle_assertion action.assert unless action.assert.nil?
      end

      def execute_operation(operation)
        return if @client.nil?
        requestHeaders = Hash[operation.requestHeader.all.map{|u| [u.field, u.value]}] #Client needs upgrade to support
        case operation.fhirType.code
        when 'read'
          if !operation.targetId.nil?
            @last_response = @client.read @fixtures[operation.targetId].class, @id_map[operation.targetId]
          else
            resource_type = operation.resource
            resource_id = operation.params
            @last_response = @client.read "FHIR::#{resource_type}", id_from_path(resource_id)
            
          end
        when 'vread'
          raise 'vread not implemented'
        when 'search'
          params = extract_operation_parameters(operation)
          @last_response = @client.search "FHIR::#{operation.resource}".constantize, search: {parameters: params}
        when 'history'
          target_id = @id_map[operation.targetId]
          fixture = @fixtures[operation.targetId]
          @last_response = @client.resource_instance_history(fixture.class,target_id)
        when 'create'
          @last_response = @client.create @fixtures[operation.sourceId]
          @id_map[operation.sourceId] = @last_response.id
        when 'update'
          target_id = @id_map[operation.targetId]
          fixture = @fixtures[operation.sourceId]
          @last_response = @client.update fixture, target_id
        when 'transaction'
          raise 'transaction not implemented'
        when 'conformance'
          raise 'conformance not implemented'
        when 'delete'
          if operation.targetId.nil?
            #todo handle conditional delete see Search
          else
            @last_response = @client.destroy @fixtures[operation.targetId].class, @id_map[operation.targetId]
            @id_map.delete(operation.targetId)
          end
        when '$expand'
          raise '$expand not supported'
          # @last_response = @client.value_set_expansion( extract_operation_parameters(operation) )
        when '$validate'
          raise '$validate not supported'
          # @last_response = @client.value_set_code_validation( extract_operation_parameters(operation) )
        else
          raise "Undefined operation for #{@testscript.name}-#{title}: #{operation.fhirType}"
        end
        handle_response(operation)
      end

      def handle_assertion(assertion)

        operator = :equals
        operator = OPERATOR_MAP[assertion.operator] unless assertion.operator.nil?

        warningOnly = false
        warningOnly = assertion.warningOnly unless assertion.warningOnly.nil?

        case
        when !assertion.contentType.nil?
          call_assertion(:assert_resource_content_type, warningOnly, @last_response, assertion.contentType)
        when !assertion.headerField.nil?
          #todo: handle abstract operators
          call_assertion(:assert_last_modified_present, warningOnly, @last_response) if operator == :notEmpty && assertion.headerField.downcase == 'last-modified'
        when !assertion.minimumId.nil?
          call_assertion(:assert_minimum, warningOnly, @last_response, @fixtures[assertion.minimumId])
          #todo
        when !assertion.navigationLinks.nil?
          #todo
        when !assertion.path.nil?
          #todo
        when !assertion.resource.nil?
          call_assertion(:assert_resource_type, warningOnly, @last_response, "FHIR::#{assertion.resource}".constantize)
        when !assertion.responseCode.nil?
          call_assertion(:assert_response_code, warningOnly, @last_response, assertion.responseCode)
        when !assertion.response.nil?
          call_assertion(:assert_response_code, warningOnly, @last_response, CODE_MAP[assertion.response])
        when !assertion.validateProfileId
          #todo
        end

      end

      def handle_assertion_old(assertion)
        # assertion = operation.parameter.first
        response = @response_map[operation.responseId] || @last_response
        if assertion.start_with? "code"
          code = assertion.split(":").last
          assertion = assertion.split(":").first
        end
        if self.methods.include?(ASSERTION_MAP[assertion])
          method = self.method(ASSERTION_MAP[assertion])
          log "ASSERTING: #{operation.fhirType} - #{assertion}"
          case assertion
          when "code"
            call_assertion(method, response, [code])
          when "resource_type"
            resource_type = "FHIR::#{operation.parameter[1]}".constantize
            call_assertion(method, response, [resource_type])
          when "response_code"
            code = operation.parameter[1]
            call_assertion(method, response, [code.to_i])
          when "equals"
            expected, actual = handle_equals(operation, response, method)
            call_assertion(method, expected, [actual])
          when "fixture_equals"
            expected, actual = handle_fixture_equals(operation, response, method)
            call_assertion(method, expected, [actual])
          when "fixture_compare"
            expected, actual = handle_fixture_compare(operation, response, method)
            call_assertion(method, expected, [actual])
          when "minimum"
            fixture_id = operation.parameter[1]
            fixture = @fixtures[fixture_id] || @response_map[fixture_id].try(:resource)
            call_assertion(method, response, [fixture])
          else
            params = operation.parameter[1..-1]
            call_assertion(method, response, params)
          end
        else
          raise "Undefined assertion for #{@testscript.name}-#{title}: #{operation.parameter}"
        end
      end

      def call_assertion(method, warned, *params)
        if warned
          warning { self.method(method).call(*params) }
        else
          self.method(method).call(*params)
        end
      end

      def extract_operation_parameters(operation)
        parameters = {}
        return parameters if operation.params.nil?
        params = operation.params
        params = operation.params[1..-1] if operation.params.length > 0 && operation.params[0] == "?"
        params.split("&").each do |param|
          key, value = param.split("=")
          parameters[key.to_sym] = value
        end unless operation.params.blank?
        parameters
      end

      def handle_response(operation)
        if !operation.responseId.blank? && operation.fhirType.code != 'delete'
          log "Overwriting response #{operation.responseId}..." if @response_map.keys.include?(operation.responseId)
          log "Storing response #{operation.responseId}..."
          @response_map[operation.responseId] = @last_response
        end
      end

      def handle_equals(operation, response, method)
        raise "#{method} expects two parameters: [expected value, actual xpath]" unless operation.parameter.length >= 3
        expected, actual = operation.parameter[1..2]
        resource_xml = response.try(:resource).try(:to_xml) || response.body

        if is_xpath(expected)
          expected = extract_xpath_value(method, resource_xml, expected)
        end
        if is_xpath(actual)
          actual = extract_xpath_value(method, resource_xml, actual)
        end

        return expected, actual
      end

      def handle_fixture_equals(operation, response, method)
        # fixture_equals(fixture-id, fixture-xpath, actual)

        fixture_id, fixture_xpath, actual = operation.parameter[1..3]
        raise "#{method} expects a fixture_id as the second operation parameter" unless !fixture_id.blank?
        raise "#{fixture_id} does not exist" unless ( @fixtures.keys.include?(fixture_id) || @response_map.keys.include?(fixture_id) )
        raise "#{method} expects a fixture_xpath as the third operation parameter" unless !fixture_xpath.blank?
        raise "#{method} expects an actual value as the fourth operation parameter" unless !actual.blank?
        raise "#{method} expects fixture_xpath to be a valid xpath" unless is_xpath(fixture_xpath)

        fixture = @fixtures[fixture_id] || @response_map[fixture_id].try(:resource)
        expected = extract_xpath_value(method, fixture.try(:to_xml), fixture_xpath)

        if is_xpath(actual)
          response_xml = response.resource.try(:to_xml) || response.body
          actual = extract_xpath_value(method, response_xml, actual)
        end

        return expected, actual
      end

      def handle_fixture_compare(operation, response, method)
        # fixture_compare(expected_fixture_id, expected_xpath, actual_fixture, actual_xpath)

        expected_fixture_id, expected_xpath, actual_fixture_id, actual_xpath = operation.parameter[1..4]
        raise "#{method} expects expected_fixture_id as the operation parameter" unless !expected_fixture_id.blank?
        raise "#{expected_fixture_id} does not exist" unless ( @fixtures.keys.include?(expected_fixture_id) || @response_map.keys.include?(expected_fixture_id) )
        raise "#{method} expects expected_xpath as the operation parameter" unless !expected_xpath.blank?
        raise "#{method} expects actual_fixture_id as the operation parameter" unless !actual_fixture_id.blank?
        raise "#{actual_fixture_id} does not exist" unless ( @fixtures.keys.include?(actual_fixture_id) || @response_map.keys.include?(actual_fixture_id) )
        raise "#{method} expects actual_xpath as the operation parameter" unless !actual_xpath.blank?

        expected_fixture = @fixtures[expected_fixture_id] || @response_map[expected_fixture_id].try(:resource)
        actual_fixture = @fixtures[actual_fixture_id] || @response_map[actual_fixture_id].try(:resource)

        raise "expected: #{expected_xpath} is not an xpath" unless is_xpath(expected_xpath)
        raise "actual: #{actual_xpath} is not an xpath" unless is_xpath(actual_xpath)
        expected = extract_xpath_value(method, expected_fixture.try(:to_xml), expected_xpath)
        actual = extract_xpath_value(method, actual_fixture.try(:to_xml), actual_xpath)

        return expected, actual
      end

      private

      # Crude method of detecting xpath expressions
      def is_xpath(value)
        value.start_with?("fhir:") && value.include?("@")
      end

      def extract_xpath_value(method, resource_xml, resource_xpath)
        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
        resource_element = resource_doc.xpath(resource_xpath)

        raise AssertionException.new("#{method} with [#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
        resource_element.first.try(:value)
      end

      def id_from_path(path)
        path[1..-1]
      end

      def get_reference(url)
        return nil unless url.start_with?('#') #todo accept more than just contained resources
        contained_id = url[1..-1]
        @testscript.contained.select{|r| r.xmlId == contained_id}.first
      end

    end
  end
end
