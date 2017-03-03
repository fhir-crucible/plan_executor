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

      def multiserver
        @testscript.origin.length >= 2 || @testscript.destination.length >= 2
      end

      def containsRuleAssertions?
        has_declared_rule = !@testscript.rule.empty? || !@testscript.ruleset.empty?
        return true if has_declared_rule

        if @testscript.setup
          has_setup_rule = @testscript.setup.action.find{ |action| action.assert && (action.assert.rule || action.assert.ruleset) }
          return true if has_setup_rule
        end

        has_test_rule = @testscript.test.find do |test|
          test.action.find{ |action| action.assert && (action.assert.rule || action.assert.ruleset) }
        end
        return true if has_test_rule

        false
      end

      def tests
        @testscript.test.map { |test| "#{test.id} #{test.name} test".downcase.tr(' ', '_').to_sym }
      end

      def debug_prefix
        "[TESTSCRIPT]:\t"
      end

      def log(message)
        output = "#{debug_prefix}#{message}"
        puts output
        FHIR.logger.info(output)
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
          @fixtures[fixture.id] = Crucible::Generator::Resources.tag_metadata(get_reference(fixture.resource.reference))
          @fixtures[fixture.id].id = nil unless @fixtures[fixture.id].nil? #fixture resources cannot have an ID
          @autocreate << fixture.id if fixture.autocreate
          @autodelete << fixture.id if fixture.autodelete
        end
      end

      def collect_metadata(_methods_only=nil)
        metadata = {}
        metadata['links'] = []
        metadata['requires'] = nil
        metadata['validates'] = nil

        if @testscript.metadata
          @testscript.metadata.link.each do |link|
            metadata['links'] << link.url
          end
          @testscript.metadata.capability.each do |capability|
            capability.link.each{|url| metadata['links'] << url }
            metadata['links'] << capability.capabilities.reference if capability.capabilities.reference
          end
        end

        {
          @testscript.id => @testscript.test.map do |test|
            {
              "key" => "#{test.id} #{test.name} test".downcase.tr(' ', '_'),
              "id" =>  "#{test.id} #{test.name} test".downcase.tr(' ', '_'),
              "description" => test.description,
              :test_method=> "#{test.id} #{test.name} test".downcase.tr(' ', '_').to_sym

            }.merge(metadata)
          end
        }

      end

      def testreport_template
        report = FHIR::TestReport.new(
              {
                'identifier' => { 'system' => 'http://projectcrucible.org', 'value' => id },
                'status' => 'complete',
                'TestScript' => { 'display' => id },
                'issued' => Time.now.to_s.sub(' ','T').sub(' ','').insert(-3,':'),
                'participant' => [
                  {
                    'type' => 'test-engine',
                    'uri' => 'http://projectcrucible.org',
                    'display' => 'plan_executor'
                  },
                  {
                    'type' => 'server',
                    'uri' => (@client ? @client.full_resource_url({}) : nil )
                  }
                ]
              })
        report.participant.pop if @client.nil?
        report
      end

      # This overrides a method of the same name in the Crucible::Tests::BaseTest base class,
      # to handle differences in the structure of the FHIR TestReport resource than Crucible's
      # internal TestResult class.
      def execute_test_methods
        @testreport = testreport_template
        begin
          @testreport.setup = setup if respond_to?(:setup) && !@metadata_only
        rescue AssertionException => e
          FHIR.logger.error "Setup Error #{id}: #{e.message}\n#{e.backtrace}"
          @setup_failed = e
          @testreport.status = 'error'
          if @testreport.setup.action.last.operation
            @testreport.setup.action.last.operation.message = "#{e.message}\n#{e.backtrace}"
          elsif @testreport.setup.action.last.assert
            @testreport.setup.action.last.assert.message = "#{e.message}\n#{e.backtrace}"
          end
        end
        prefix = if @metadata_only then 'generating metadata' else 'executing' end
        methods = tests
        methods = tests & @tests_subset unless @tests_subset.blank?
        methods.each do |test_method|
          @client.requests = [] if @client
          FHIR.logger.info "[#{title}#{('_' + @resource_class.name.demodulize) if @resource_class}] #{prefix}: #{test_method}..."
          begin
            @testreport.test << self.method(test_method).call
          rescue => e
            FHIR.logger.error "Fatal Error executing #{id} #{test_method}: #{e.message}\n#{e.backtrace}"
            @testreport.status = 'error'
            if @testreport.test.last.action.last.operation
              @testreport.test.last.action.last.operation.message = "#{e.message}\n#{e.backtrace}"
            elsif @testreport.test.last.action.last.assert
              @testreport.test.last.action.last.assert.message = "#{e.message}\n#{e.backtrace}"
            end
          end
        end
        begin
          @testreport.teardown = teardown if respond_to?(:teardown) && !@metadata_only
        rescue
        end
        @testreport
      end

      # Returns a FHIR::TestReport::Test
      def process_test(test)
        result = FHIR::TestReport::Test.new({
            'name' => test.id,
            'description' => test.description,
            'action' => []
          })
        @current_test = test
        @last_response = nil # clear out any responses from previous tests
        @test_failed = false
        begin
          test.action.each do |action|
            if !@test_failed
              @current_action = action
              result.action << perform_action(action)
              @test_failed = true if action_failed?(result.action.last)
            end
          end unless @metadata_only
        rescue => e
          @testreport.status = 'error'
          FHIR.logger.error "Fatal Error processing TestScript #{test.id} Action: #{e.message}\n#{e.backtrace}"
        end
        result
      end

      def action_failed?(action)
        return true if action.nil?
        if action.operation
          ['fail','error'].include?(action.operation.result)
        elsif action.assert
          ['fail','error'].include?(action.assert.result)
        else
          true
        end
      end

      # Returns a FHIR::TestReport::Setup
      def setup
        return nil if @testscript.setup.blank? && @autocreate.empty?
        report_setup = FHIR::TestReport::Setup.new
        @current_test = :setup
        @setup_failed = false
        # Run any autocreates
        @autocreate.each do |fixture_id|
          if !@setup_failed
            @current_action = "Autocreate Fixture #{fixture_id}"
            @last_response = @client.create @fixtures[fixture_id]
            @id_map[fixture_id] = @last_response.id
            report_setup.action << FHIR::TestReport::Setup::Action.new({
                'operation' => {
                  'result' => ( [200,201].include?(@last_response.code) ? 'pass' : 'fail' ),
                  'message' => @current_action
                }
              })
            @setup_failed = true unless [200,201].include?(@last_response.code)
          end
        end unless @client.nil?
        # Run setup actions if any
        @testscript.setup.action.each do |action|
          if !@setup_failed
            @current_action = action
            report_setup.action << perform_action(action) 
            @setup_failed = true if action_failed?(report_setup.action.last)
          end
        end unless @testscript.setup.blank?
        report_setup
      end

      # Returns a FHIR::TestReport::Teardown
      def teardown
        return nil if @testscript.teardown.blank? && @autodelete.empty?
        report_teardown = FHIR::TestReport::Teardown.new
        # First run teardown as normal
        @testscript.teardown.action.each do |action|
          report_teardown.action << perform_action(action)
        end unless @testscript.teardown.blank?
        # Next autodelete any auto fixtures
        @autodelete.each do |fixture_id|
          @last_response = @client.destroy @fixtures[fixture_id].class, @id_map[fixture_id]
          @id_map.delete(fixture_id)
          report_teardown.action << FHIR::TestReport::Setup::Action.new({
              'operation' => {
                'result' => ( [200,204].include?(@last_response.code) ? 'pass' : 'fail' ),
                'message' => "Autodelete Fixture #{fixture_id}"
              }
            })
        end unless @client.nil?
        report_teardown
      end

      # Returns a FHIR::TestReport::Setup::Action
      # containing either a FHIR::TestReport::Setup::Action::Operation
      #                or a FHIR::TestReport::Setup::Action::Assert
      def perform_action(action)
        result = FHIR::TestReport::Setup::Action.new
        if action.operation
          result.operation = execute_operation(action.operation)
        elsif action.assert
          result.assert = handle_assertion(action.assert)
        end
        result
      end

      # Returns a FHIR::TestReport::Setup::Action::Operation
      def execute_operation(operation)
        return nil if @client.nil?
        result = FHIR::TestReport::Setup::Action::Operation.new({
          'result' => 'pass',
          'message' => operation.description
          })

        requestHeaders = Hash[(operation.requestHeader || []).map{|u| [u.field, u.value]}] #Client needs upgrade to support
        format = FHIR::Formats::ResourceFormat::RESOURCE_XML
        format = FORMAT_MAP[operation.contentType] unless operation.contentType.nil?
        format = FORMAT_MAP[operation.accept] unless operation.accept.nil?

        operationCode = 'empty'
        operationCode = operation.type.code unless operation.type.nil?

        case operationCode
        when 'read'
          if operation.targetId
            @last_response = @client.read @fixtures[operation.targetId].class, @id_map[operation.targetId], format
          elsif operation.url
            @last_response = @client.get replace_variables(operation.url), @client.fhir_headers({ format: format})
            @last_response.resource = FHIR.from_contents(@last_response.body)
            @last_response.resource_class = @last_response.resource.class
          else
            resource_type = replace_variables(operation.resource)
            resource_id = replace_variables(operation.params)
            @last_response = @client.read "FHIR::#{resource_type}".constantize, id_from_path(resource_id), format
          end
        when 'vread'
          if operation.url
            @last_response = @client.get replace_variables(operation.url), @client.fhir_headers({ format: format})
            @last_response.resource = FHIR.from_contents(@last_response.body)
            @last_response.resource_class = @last_response.resource.class
          else
            resource_type = replace_variables(operation.resource)
            resource_id = replace_variables(operation.params)
            @last_response = @client.read "FHIR::#{resource_type}".constantize, resource_id, format
          end
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
        when 'update','updateCreate'
          target_id = nil
          
          if !operation.targetId.nil? 
            target_id = @id_map[operation.targetId]
          elsif !operation.params.nil?
            target_id = id_from_path(replace_variables(operation.params))
          end

          fixture = @fixtures[operation.sourceId]
          fixture.id = replace_variables(target_id) if fixture.id.nil?
          @last_response = @client.update fixture, replace_variables(target_id), format
        when 'transaction'
          result.result = 'error'
          result.message = 'transaction not implemented'
        when 'conformance'
          result.result = 'error'
          result.message = 'conformance not implemented'
        when 'delete'
          if operation.targetId.nil?
            params = replace_variables(operation.params)
            @last_response = @client.destroy "FHIR::#{operation.resource}".constantize, nil, params: params
          else
            @last_response = @client.destroy @fixtures[operation.targetId].class, @id_map[operation.targetId]
            @id_map.delete(operation.targetId)
          end
        when '$expand'
          result.result = 'error'
          result.message = '$expand not supported'
          # @last_response = @client.value_set_expansion( extract_operation_parameters(operation) )
        when '$validate'
          result.result = 'error'
          result.message = '$validate not supported'
          # @last_response = @client.value_set_code_validation( extract_operation_parameters(operation) )
        when '$validate-code'
          result.result = 'error'
          result.message = '$validate-code not supported'
          # options = {
          #   :operation => {
          #     :method => 'GET',
          #     :parameters => {
          #       'code' => { type: 'Code', value: params['code'] },
          #       'identifier' => { type: 'Uri', value: params['system'] }
          #     }
          #   }
          # }
          # @last_response = @client.value_set_code_validation(options)
        when 'empty'
          if !operation.params.nil? && !operation.resource.nil?
            resource = "FHIR::#{operation.resource}".constantize 
            @last_response = @client.read resource, nil, FORMAT_MAP[operation.accept], nil, params: replace_variables(operation.params)
          end
        else
          result.result = 'error'
          result.message = "Undefined operation #{operation.type.to_json}"
          FHIR.logger.error(result.message)
        end
        handle_response(operation)
        result
      end

      # Returns a FHIR::TestReport::Setup::Action::Assert
      def handle_assertion(assertion)
        result = FHIR::TestReport::Setup::Action::Assert.new({
          'result' => 'pass',
          'message' => assertion.label || assertion.description
          })

        operator = :equals
        operator = OPERATOR_MAP[assertion.operator] unless assertion.operator.nil?

        warningOnly = false
        warningOnly = assertion.warningOnly unless assertion.warningOnly.nil?

        begin
          case
          when !assertion.contentType.nil?
            call_assertion(:assert_resource_content_type, @last_response, assertion.contentType)

          when !assertion.headerField.nil?
            if assertion.direction && assertion.direction=='request'
              header_value = @last_response.request[:headers][assertion.headerField]
              msg_prefix = 'Request'
            else
              header_value = @last_response.response[:headers][assertion.headerField.downcase]
              msg_prefix = 'Response'
            end
            call_assertion(:assert_operator, operator, replace_variables(assertion.value), header_value, "#{msg_prefix} Header field #{assertion.headerField}")
          when !assertion.minimumId.nil?
            call_assertion(:assert_minimum, @last_response, @fixtures[assertion.minimumId])

          when !assertion.navigationLinks.nil?
            call_assertion(:assert_navigation_links, @last_response.resource)

          when !assertion.path.nil?
            actual_value = nil
            resource = nil
            if assertion.sourceId.nil?
              resource = @last_response.try(:resource) || FHIR.from_contents(@last_response.body)
            else
              resource = @fixtures[assertion.sourceId]
              resource = @response_map[assertion.sourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.sourceId].body) if resource.nil?
            end
            actual_value = extract_value_by_path(resource, assertion.path)

            expected_value = replace_variables(assertion.value)
            unless assertion.compareToSourceId.nil?
              resource = @fixtures[assertion.compareToSourceId]
              resource = @response_map[assertion.compareToSourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.compareToSourceId].body) if resource.nil?
              expected_value = extract_value_by_path(resource, assertion.path)
            end

            call_assertion(:assert_operator, operator, expected_value, actual_value)
          when !assertion.compareToSourcePath.nil?
            actual_value = nil
            resource = nil
            if assertion.sourceId
              resource = @fixtures[assertion.sourceId]
              resource = @response_map[assertion.sourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.sourceId].body) if resource.nil?
            else
              raise AssertionException.new("compareToSourcePath requires sourceId: #{assertion.to_json}")
            end
            actual_value = extract_value_by_path(resource, assertion.compareToSourcePath)

            expected_value = replace_variables(assertion.value)
            unless assertion.compareToSourceId.nil?
              resource = @fixtures[assertion.compareToSourceId]
              resource = @response_map[assertion.compareToSourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.compareToSourceId].body) if resource.nil?
              expected_value = extract_value_by_path(resource, assertion.compareToSourcePath)
            end

            call_assertion(:assert_operator, operator, expected_value, actual_value)
          when !assertion.resource.nil?
            call_assertion(:assert_resource_type, @last_response, "FHIR::#{assertion.resource}".constantize)

          when !assertion.responseCode.nil?
            call_assertion(:assert_operator, operator, assertion.responseCode, @last_response.response[:code].to_s)

          when !assertion.response.nil?
            call_assertion(:assert_response_code, @last_response, CODE_MAP[assertion.response])

          when !assertion.validateProfileId.nil?
            profile_uri = @testscript.profile.first{|p| p.id = assertion.validateProfileId}.reference
            reply = @client.validate(@last_response.resource,{profile_uri: profile_uri})
            call_assertion(:assert_valid_profile, reply.response, @last_response.resource.class)

          when !assertion.expression.nil?
            resource = nil
            if assertion.sourceId.nil?
              resource = @last_response.try(:resource) || FHIR.from_contents(@last_response.body)
            else
              resource = @fixtures[assertion.sourceId]
              resource = @response_map[assertion.sourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.sourceId].body) if resource.nil?
            end
            begin
              unless FluentPath.evaluate(assertion.expression, resource.to_hash)
                raise AssertionException.new("Expression did not evaluate to true: #{assertion.expression}", assertion.expression)
              end
            rescue => fpe
              raise "Invalid Expression: #{assertion.expression}"
            end
          when !assertion.compareToSourceExpression.nil?
            resource = nil
            if assertion.sourceId
              resource = @fixtures[assertion.sourceId]
              resource = @response_map[assertion.sourceId].try(:resource) || FHIR.from_contents(@response_map[assertion.sourceId].body) if resource.nil?
            else
              raise AssertionException.new("compareToSourceExpression requires sourceId: #{assertion.to_json}")
            end
            begin
              unless FluentPath.evaluate(assertion.compareToSourceExpression, resource.to_hash)
                raise AssertionException.new("Expression did not evaluate to true: #{assertion.compareToSourceExpression}", assertion.compareToSourceExpression)
              end
            rescue => fpe
              raise "Invalid Expression: #{assertion.compareToSourceExpression}"
            end
          else
            result.result = 'error'
            result.message = "Unhandled Assertion: #{assertion.to_json}"
          end
        rescue AssertionException => ae
          result.result = 'fail'
          result.result = 'warning' if warningOnly
          result.message = ae.message
        rescue => e
          result.result = 'error'
          result.message = "#{e.message}\n#{e.backtrace}"
        end

        result
      end

      def call_assertion(method, *params)
        FHIR.logger.debug "Assertion: #{method}"
        self.method(method).call(*params)
      end

      def replace_variables(input)
        return nil if input.nil?
        return input unless input.include?('${')

        @testscript.variable.each do |var|
          if input.include? "${#{var.name}}"
            variable_value = nil

            if !var.headerField.nil?
              variable_source_response = @response_map[var.sourceId]
              headers = variable_source_response.response[:headers]
              headers.each do |key,value|
                variable_value = value if key.downcase == var.headerField.downcase
              end
            elsif !var.path.nil?

              resource = nil
              variable_source_response = @response_map[var.sourceId]
              unless variable_source_response.nil?
                resource = variable_source_response.try(:resource) || FHIR.from_contents(variable_source_response.body)
              else
                resource = @fixtures[var.sourceId]
              end

              variable_value = extract_value_by_path(resource, var.path)
            end

            unless variable_value
              if var.defaultValue
                variable_value = var.defaultValue
              else
                variable_value = ''
              end
            end

            input.gsub!("${#{var.name}}", variable_value)
          end
        end

        if input.include? '${'
          unknown_variables = input.scan(/(\$\{)([A-Za-z0-9\_]+)(\})/).map{|x|x[1]}
          message = "Unknown variables: #{unknown_variables.join(', ')}"
          log message
          warning {  assert unknown_variables.empty?, message }
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

      def extract_value_by_path(resource, path)
        result = nil
        begin
          # First, try xpath
          result = extract_xpath_value(resource.to_xml, path)
        rescue
          # If xpath fails, see if JSON path will work...
          result = JsonPath.new(path).first(resource.to_json)
        end
        result
      end

      def extract_xpath_value(resource_xml, resource_xpath)
        # Massage the xpath if it doesn't have fhir: namespace or if doesn't end in @value
        # Also make it look in the entire xml document instead of just starting at the root
        xpath = resource_xpath.split("/").map{|s| if s.starts_with?('fhir:') || s.length == 0 || s.starts_with?('@') then s else "fhir:#{s}" end}.join('/')
        xpath = "#{xpath}/@value" unless xpath.ends_with? '@value'
        xpath = "//#{xpath}"

        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
        resource_element = resource_doc.xpath(xpath)

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
        elsif reference.start_with?('http')
          raise "Remote references not supported: #{reference}"
        else 
          filepath = File.expand_path reference, File.dirname(File.absolute_path(@testscript.url))
          return nil unless File.exist? filepath
          file = File.open(filepath, 'r:UTF-8', &:read)
          file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
          file = preprocess(file) if file.include?('${')
          resource = FHIR.from_contents(file)
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
            code_matches = /^(C|c|D|d|CD|cd)(\d+)$/.match(match[0])
            next unless code_matches && code_matches.size == 3
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
