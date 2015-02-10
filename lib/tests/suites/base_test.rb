module Crucible
  module Tests
    class BaseTest

      include Crucible::Tests::Assertions

      BASE_SPEC_LINK = 'http://www.hl7.org/implement/standards/fhir'
      REST_SPEC_LINK = "#{BASE_SPEC_LINK}/http.html"

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title', 'multiserver']
      STATUS = {
        pass: 'pass',
        fail: 'fail',
        error: 'error',
        skip: 'skip'
      }

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
      end

      def multiserver
        false
      end

      def execute
        [{test_name => {
            test_file: test_name,
            tests: execute_test_methods
        }}]
      end

      def execute_test_methods(test_methods=nil)
        result = []
        setup if respond_to? :setup and not @metadata_only
        prefix = if @metadata_only then 'generating metadata' else 'executing' end
        methods = tests
        methods = tests & test_methods unless test_methods.blank?
        methods.each do |test_method|
          puts "[#{test_name}#{('_' + @resource_class.name.demodulize) if @resource_class}] #{prefix}: #{test_method}..."
          begin
            result << execute_test_method(test_method)
          rescue => e
            result << TestResult.new('ERROR', "Error #{prefix} #{test_method}", STATUS[:error], "#{test_method} failed, fatal error: #{e.message}", e.backtrace.join("\n")).to_hash.merge!({:test_method => test_method})
          end
        end
        teardown if respond_to? :teardown and not @metadata_only
        result
      end

      def execute_test_method(test_method)
        self.method(test_method).call().to_hash.merge!({:test_method => test_method})
      end

      def author
        # String identifying test file author
        self.class.name
      end

      def description
        # String containing test file description
        self.class.name
      end

      def id
        # String used to order test files for execution
        self.object_id.to_s
      end

      def test_name
        self.class.name.demodulize.to_sym
      end

      def tests(keys=nil)
        # Array of test methods within test file
        methods = self.methods.grep(/_test$/)
        if keys
          matches = []
          keys.each do |key|
            matches << methods.grep(/^#{key}/i)
          end
          methods = matches.flatten
        end
        methods
      end

      def title
        # String containing test file title
        self.class.name.split('::').last
      end

      # timestamp?

      def parse_operation_outcome(body)
        # body should be a String
        outcome = nil
        if 0==(body =~ /^[<?xml]/)
          outcome = FHIR::OperationOutcome.from_xml(body)
        else # treat as JSON
          outcome = FHIR::OperationOutcome.from_fhir_json(body)
        end
        outcome
      end

      def build_messages(operation_outcome)
        messages = []
        if !operation_outcome.nil? and !operation_outcome.issue.nil?
          operation_outcome.issue.each {|issue| messages << "#{issue.severity} : #{issue.details}" }
        end
        messages
      end

      def fhir_resources
        Mongoid.models.select {|c| c.name.include?('FHIR') && !c.included_modules.find_index(FHIR::Resource).nil?}
      end

      def warning
        begin
          yield
        rescue AssertionException => e
          @warnings << e.message
        end
      end

      def requires(hash)
        @requires << hash
      end

      def validates(hash)
        @validates << hash
      end

      def links(url)
        @links << url
      end

      def collect_metadata(methods_only=false)
        @metadata_only = true
        if @resource_class
          result = execute(@resource_class)
        else
          result = execute
        end
        result = result.map{|r| r.values.first[:tests]}.flatten if methods_only
        @metadata_only = false
        result
      end

      def metadata(&block)
        yield
        skip if @metadata_only
      end

      def tests_by_conformance(conformance_resources=nil, metadata=nil)
        return tests unless conformance_resources
        # array of metadata from current suite's test methods
        suite_metadata = metadata || collect_metadata(true)
        # { fhirType => supported codes }
        methods = []
        # include tests with undefined metadata
        methods.push suite_metadata.select{|sm| sm["requires"].blank?}.map {|sm| sm[:test_method]}
        # parse tests with defined metadata
        suite_metadata.select{|sm| !sm["requires"].blank?}.each do |test|
          unsupported = []
          # determine if any of the metadata requirements match the conformance information
          test["requires"].each do |req|
            diffs = (req[:methods] - ( conformance_resources[req[:resource]] || [] ))
            unsupported.push({req[:resource].to_sym => diffs}) unless diffs.blank?
          end
          # print debug if unsupported, otherwise add to supported methods
          if !unsupported.blank?
            puts "UNSUPPORTED #{test[:test_method]}: #{unsupported}"
          else
            methods.push test[:test_method]
          end
        end
        methods.flatten
      end

      def self.test(key, desc, &block)
        test_method = "#{key} #{desc} test".downcase.tr(' ', '_').to_sym
        contents = block
        wrapped = -> () do
          @warnings, @links, @requires, @validates = [],[],[],[]
          description = nil
          if respond_to? :supplement_test_description
            description = supplement_test_description(desc)
          else
            description = desc
          end
          result = TestResult.new(key, description, STATUS[:pass], '','')
          begin
            t = instance_eval &block
            result.update(t.status, t.message, t.data) if !t.nil? && t.is_a?(Crucible::Tests::TestResult)
          rescue AssertionException => e
            result.update(STATUS[:fail], e.message, e.data)
          rescue SkipException => e
            result.update(STATUS[:skip], "Skipped: #{test_method}", '')
          rescue => e
            result.update(STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
          end
          result.warnings = @warnings  unless @warnings.empty?
          result.requires = @requires unless @requires.empty?
          result.validates = @validates unless @validates.empty?
          result.links = @links unless @links.empty?
          result.id = key
          result.code = contents.source
          result.id = "#{result.id}_#{result_id_suffix}" if respond_to? :result_id_suffix # add the resource to resource based tests to make ids unique

          result
        end
        define_method test_method, wrapped
      end

    end

  end
end
