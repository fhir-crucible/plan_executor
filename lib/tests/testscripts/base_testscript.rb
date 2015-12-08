module Crucible
  module Tests
    class BaseTestScript < BaseTest

      # variables todo:
      # Implement in:
      # - operation.params
      # - operation.requestHeader.value
      # - operation.url
      #
      # doing next: paths.  see xpath stuff.
      #
      # do accept
      
      FORMAT_MAP = {
        'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
        'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
      }

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

      HEADERFIELD_MAP = {
        'Location' => 'content-location'
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
        @warnings = [] # clear out any previous warnings
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
          result.requires = []
          result.validates = []
          conformances = test.metadata.capability.map(&:conformance).map{|c| get_reference(c.reference)}
          conformances.each do |conf|
            conf.rest.each do |rest|
              validates = rest.resource.map{|resource| { resource: resource.fhirType, methods: resource.interaction.map(&:code)}}
              result.requires.concat(validates)
              result.validates.concat(validates) # should this come from elsewhere?
            end
          end

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
        #requestheaders can support variables
        requestHeaders = Hash[operation.requestHeader.all.map{|u| [u.field, u.value]}] #Client needs upgrade to support
        format = FHIR::Formats::ResourceFormat::RESOURCE_XML
        format = FORMAT_MAP[operation.contentType] unless operation.contentType.nil?
        format = FORMAT_MAP[operation.accept] unless operation.accept.nil?
        case operation.fhirType.code
        when 'read'
          if !operation.targetId.nil?
            @last_response = @client.read @fixtures[operation.targetId].class, @id_map[operation.targetId]
          else
            resource_type = replace_variables(operation.resource)
            resource_id = replace_variables(operation.params)
            @last_response = @client.read "FHIR::#{resource_type}".constantize, id_from_path(resource_id)
          end
        when 'vread'
          raise 'vread not implemented'
        when 'search'
          if operation.url.nil?
            params = extract_operation_parameters(operation)
            @last_response = @client.search "FHIR::#{operation.resource}".constantize, {search: {parameters: params}}, format
          else
            url = replace_variables(operation.url)
            last_response = @client.search "FHIR::#{operation.resource}".constantize, url: url
          end
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
          call_assertion(:assert_operator, warningOnly, operator, replace_variables(assertion.value), @last_response.response[:headers][assertion.headerField.downcase], "Header field #{assertion.headerField}")

        when !assertion.minimumId.nil?
          call_assertion(:assert_minimum, warningOnly, @last_response, @fixtures[assertion.minimumId])

        when !assertion.navigationLinks.nil?
          #todo

        when !assertion.path.nil?
          actual_value = nil
          if is_xpath(assertion.path)
            resource_xml = nil
            if assertion.sourceId.nil?
              resource_xml = @last_response.try(:resource).try(:to_xml) || @last_response.body
            else
              resource_xml = @fixtures[assertion.sourceId].try(:to_xml)
            end

            actual_value = extract_xpath_value(resource_xml, assertion.path)
          end

          expected_value = replace_variables(assertion.value)
          unless assertion.compareToSourceId.nil?
            resource_xml = @fixtures[assertion.compareToSourceId].try(:to_xml)
            resource_xml = @response_map[assertion.compareToSourceId].try(:resource).try(:to_xml) || @response_map[assertion.compareToSourceId].body if resource_xml.nil?

            expected_value = extract_xpath_value(resource_xml, assertion.path)
          end

          call_assertion(:assert_operator, warningOnly, operator, expected_value, actual_value)

        when !assertion.resource.nil?
          call_assertion(:assert_resource_type, warningOnly, @last_response, "FHIR::#{assertion.resource}".constantize)

        when !assertion.responseCode.nil?
          call_assertion(:assert_response_code, warningOnly, @last_response, assertion.responseCode)

        when !assertion.response.nil?
          call_assertion(:assert_response_code, warningOnly, @last_response, CODE_MAP[assertion.response])

        when !assertion.validateProfileId
          #todo
          #
        end

      end

      def call_assertion(method, warned, *params)
        if warned
          warning { self.method(method).call(*params) }
        else
          self.method(method).call(*params)
        end
      end

      def replace_variables(input)
        return nil if input.nil?

        @testscript.variable.each do |var|
          variable_source = @response_map[var.sourceId]
          if !var.headerField.nil?
            variable_value = variable_source.response[:headers][HEADERFIELD_MAP[var.headerField]]
            input.sub!("${" + var.name + "}", variable_value)
          elsif !var.path.nil?

            if is_xpath(var.path)
              resource_xml = variable_source.try(:resource).try(:to_xml) || variable_source.body
              extracted_value = extract_xpath_value(resource_xml, var.path)
              input = input.sub("${" + var.name + "}", extracted_value) unless extracted_value.nil?
            end unless variable_source.nil? or !input.include? "${" + var.name + "}"

          end
        end

        input

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

      # Crude method of detecting xpath expressions
      def is_xpath(value)
        value.start_with?("fhir:") && value.include?("@")
      end

      def extract_xpath_value(resource_xml, resource_xpath)
        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
        resource_element = resource_doc.xpath(resource_xpath)

        raise AssertionException.new("[#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
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
