module Crucible
  module Tests
    class BaseTestScript < BaseTest
      
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
        @category = {id: 'testscript', title: 'TestScript'}
        @id_map = {}
        @response_map = {}
        @warnings = []
        @autocreate = []
        @autodelete = []
        @testscript = testscript
        @preprocessed_vars = {}
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
        @testscript.id
      end

      def title
        "TS-#{id}"
      end

      def tests
        @testscript.test.map { |test| "#{test.id} #{test.name} test".downcase.tr(' ', '_').to_sym }
      end

      def debug_prefix
        "[TESTSCRIPT]:\t"
      end

      def log(message)
        puts "#{debug_prefix}#{message}"
      end

      def define_tests
        @testscript.test.each do |test|
          test_method = "#{test.id} #{test.name} test".downcase.tr(' ', '_').to_sym
          define_singleton_method test_method, -> { process_test(test) }
        end
      end

      def load_fixtures
        @fixtures = {}
        @testscript.fixture.each do |fixture|
          @fixtures[fixture.id] = get_reference(fixture.resource.reference)
          @fixtures[fixture.id].id = nil unless @fixtures[fixture.id].nil? #fixture resources cannot have an ID
          @autocreate << fixture.id if fixture.autocreate
          @autodelete << fixture.id if fixture.autodelete
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
        result = TestResult.new("TS_#{test.id}", test.name, STATUS[:pass], '','')
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
        result.requires = []
        result.validates = []
        unless test.metadata.nil?
          test.metadata.capability.each do |capability|
            conf = get_reference(capability.conformance.reference)
            conf.rest.each do |rest|
              interactions = rest.resource.map{|resource| { resource: resource.type, methods: resource.interaction.map(&:code)}}
              result.requires.concat(interactions) if capability.required
              result.validates.concat(interactions) if capability.fhirValidated
            end
          end
          result.links = test.metadata.capability.map(&:link).flatten.uniq
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
        requestHeaders = Hash[(operation.requestHeader || []).map{|u| [u.field, u.value]}] #Client needs upgrade to support
        format = FHIR::Formats::ResourceFormat::RESOURCE_XML
        format = FORMAT_MAP[operation.contentType] unless operation.contentType.nil?
        format = FORMAT_MAP[operation.accept] unless operation.accept.nil?

        operationCode = 'empty'
        operationCode = operation.type.code unless operation.type.nil?

        case operationCode
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
            @last_response = @client.search "FHIR::#{operation.resource}".constantize, url: url #todo implement URL
          end
        when 'history'
          target_id = @id_map[operation.targetId]
          fixture = @fixtures[operation.targetId]
          @last_response = @client.resource_instance_history(fixture.class,target_id)
        when 'create'
          @last_response = @client.base_create(@fixtures[operation.sourceId], requestHeaders, format)
          @id_map[operation.sourceId] = @last_response.id
        when 'update'
          target_id = nil
          
          if !operation.targetId.nil? 
            target_id = @id_map[operation.targetId]
          elsif !operation.params.nil?
            target_id = id_from_path(replace_variables(operation.params))
          end

          raise "No target specified for update" if target_id.nil?

          fixture = @fixtures[operation.sourceId]
          fixture.id = replace_variables(target_id) if fixture.id.nil?
          @last_response = @client.update fixture, replace_variables(target_id), format
        when 'transaction'
          raise 'transaction not implemented'
        when 'conformance'
          raise 'conformance not implemented'
        when 'delete'
          if operation.targetId.nil?
            params = replace_variables(operation.params)
            @last_response = @client.destroy "FHIR::#{operation.resource}".constantize, nil, params: params
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
        when '$validate-code'
          raise 'could not find params for $validate-code' unless operation.params

          params = nil
          # TODO: need to figure this out          
          # if operation.params =~ URI::regexp
          #   params = CGI.parse(URI.parse(operation.params).query)
          # end

          raise 'could not find any parameters for $validate-code' unless params
          raise 'could not find system for $validate-code' unless params['system']
          raise 'could not find code for $validate-code' unless params['code']

          options = {
            :operation => {
              :method => 'GET',
              :parameters => {
                'code' => { type: 'Code', value: params['code'] },
                'identifier' => { type: 'Uri', value: params['system'] }
              }
            }
          }
          @last_response = @client.value_set_code_validation(options)

        when 'empty'

          if !operation.params.nil? && !operation.resource.nil?
            resource = "FHIR::#{operation.resource}".constantize 
            @last_response = @client.read resource, nil, FORMAT_MAP[operation.accept], nil, params: replace_variables(operation.params)
          end 

        else
          raise "Undefined operation for #{@testscript.name}-#{title}: #{operation.type}"
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
          call_assertion(:assert_navigation_links, warningOnly, @last_response.resource)

        when !assertion.path.nil?
          actual_value = nil

          resource_xml = nil
          if assertion.sourceId.nil?
            resource_xml = @last_response.try(:resource).try(:to_xml) || @last_response.body
          else
            resource_xml = @fixtures[assertion.sourceId].try(:to_xml)
            resource_xml = @response_map[assertion.sourceId].try(:resource).try(:to_xml) || @response_map[assertion.soureId].body if resource_xml.nil?
          end

          actual_value = extract_xpath_value(resource_xml, assertion.path)

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
          call_assertion(:assert_operator, warningOnly, operator, assertion.responseCode, @last_response.response[:code], "Response Code #{assertion.responseCode}")

          # call_assertion(:assert_response_code, warningOnly, @last_response, assertion.responseCode)

        when !assertion.response.nil?
          call_assertion(:assert_response_code, warningOnly, @last_response, CODE_MAP[assertion.response])

        when !assertion.validateProfileId.nil?
          profile_uri = @testscript.profile.first{|p| p.id = assertion.validateProfileId}.reference
          reply = @client.validate(@last_response.resource,{profile_uri: profile_uri})
          call_assertion(:assert_valid_profile, warningOnly, reply.response, @last_response.resource.class)

        else
          raise "Unknown Assertion"

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
          if !var.headerField.nil?
            variable_source_response = @response_map[var.sourceId]
            variable_value = variable_source_response.response[:headers][var.headerField]
            input.gsub!("${" + var.name + "}", variable_value)
          elsif !var.path.nil?

            resource_xml = nil
            
            variable_source_response = @response_map[var.sourceId]
            unless variable_source_response.nil?
              resource_xml = variable_source_response.try(:resource).try(:to_xml) || variable_source_response.body
            else
              resource_xml = @fixtures[var.sourceId].to_xml
            end

            extracted_value = extract_xpath_value(resource_xml, var.path)

            input.gsub!("${" + var.name + "}", extracted_value) unless extracted_value.nil?

          end if input.include? "${" + var.name + "}"
        end

        if input.include? '${'
          puts "An unknown variable was unable to be replaced: #{input}!"
          warning {  assert !input.include?('${'), "An unknown variable was unable to be substituted: #{input}" }
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
          parameters[key.to_sym] = replace_variables(value)
        end unless operation.params.blank?
        parameters
      end

      def handle_response(operation)
        if !operation.responseId.blank? && operation.type.code != 'delete'
          log "Overwriting response #{operation.responseId}..." if @response_map.keys.include?(operation.responseId)
          log "Storing response #{operation.responseId}..."
          @response_map[operation.responseId] = @last_response
        end
      end

      def extract_xpath_value(resource_xml, resource_xpath)

        # Massage the xpath if it doesn't have fhir: namespace or if doesn't end in @value
        # Also make it look in the entire xml document instead of just starting at the root
        resource_xpath = resource_xpath.split("/").map{|s| if s.starts_with?("fhir:") || s.length == 0 then s else "fhir:#{s}" end}.join("/")
        resource_xpath = "#{resource_xpath}/@value" unless resource_xpath.ends_with? "/@value"
        resource_xpath = "//#{resource_xpath}"

        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
        resource_element = resource_doc.xpath(resource_xpath)

        # This doesn't work on warningOnly; consider putting back in place
        # raise AssertionException.new("[#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
        resource_element.first.try(:value)
      end

      def id_from_path(path)
        path[1..-1]
      end

      def get_reference(reference)
        resource = nil
        if reference.start_with?('#')
          contained_id = reference[1..-1]
          resource = @testscript.contained.select{|r| r.id == contained_id}.first
        else 
          root = File.expand_path '.', File.dirname(File.absolute_path(__FILE__))
          return nil unless File.exist? "#{root}/xml#{reference}"
          file = File.open("#{root}/xml#{reference}", "r:UTF-8", &:read)
          file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
          file = preprocess(file) if file.include?('${')
          if reference.split('.').last == "json"
            resourceType = JSON.parse(file)["resourceType"]
            resource = FHIR::Json.from_json(file)
          else
            resourceType = Nokogiri::XML(file).children.find{|x| x.class == Nokogiri::XML::Element}.name
            resource = FHIR::Xml.from_xml(file)

          end
        end

        resource
      end

      def preprocess(input)
        # ${C4}: generates a 4 character string
        # ${D5}: generates a 5 digit number
        # ${CD6}: generates a 6 character string with digits and characters
        output = input;
        input.scan(/\${(\w+)}/).each do |match| 
          if @preprocessed_vars.key?(match[0])
            output.sub!("${#{match[0]}}", @preprocessed_vars[match[0]])
          else
            code_matches = /^([a-zA-Z]+)(\d+)$/.match(match[0])
            continue unless code_matches.size == 3 
            mock_data = generate_mock_data(code_matches[1], code_matches[2].to_i)
            output.sub!("${#{match[0]}}", mock_data)
            @preprocessed_vars[match[0]] = mock_data
          end
        end

        output
      end

      def generate_mock_data(type, length)
        choices = []
        choices << ('a'..'z') << ('A'..'Z') if type.downcase.include?('c') #add uppercase and lowercase characters as a choice
        choices << (0..9) if type.downcase.include?('d') #add digits as a choice
        (choices * length).map(&:to_a).flatten.shuffle[0,length].join #generate a random string based on all the choices
      end
    end
  end
end
