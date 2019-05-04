module Crucible
  module Tests
    class BaseTest

      include Crucible::Tests::Assertions
      require 'method_source'

      BASE_SPEC_LINK = 'http://hl7.org/fhir'
      REST_SPEC_LINK = "#{BASE_SPEC_LINK}/http.html"

      attr_accessor :tests_subset
      attr_accessor :tags
      attr_accessor :category
      attr_accessor :warnings
      attr_accessor :setup_failed
      attr_accessor :setup_failure_message
      attr_accessor :setup_requests
      attr_accessor :teardown_requests
      attr_accessor :supported_versions

      # Used to keep track of what order the tests are defined
      # At some point ruby started not returning the order of methods defined consistently (>2.4ish)
      # So we need to now save the order that tests were defined
      @@ordered_tests = []

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title', 'multiserver', 'tags', 'details', 'category','supported_versions']
      STATUS = {
        pass: 'pass',
        fail: 'fail',
        error: 'error',
        skip: 'skip'
      }
      METADATA_FIELDS = ['links', 'requires', 'validates']

      def initialize(client, client2=nil)
        @client = client
        FHIR::Resource.new.client = client
        FHIR::DSTU2::Resource.new.client = client
        FHIR::STU3::Resource.new.client = client
        @client2 = client2
        @client.monitor_requests if @client
        @client2.monitor_requests if @client2
        @tags ||= []
        @supported_versions ||= [:dstu2, :stu3]
        @warnings = []
        @setup_failed = false
        @setup_requests = []
        @teardown_requests = []
      end

      def multiserver
        false
      end

      def execute
        @client.use_format_param = false if @client
        @client2.use_format_param = false if @client2
        {id => execute_test_methods}
      end

      def requires_authorization
        true
      end

      def execute_test_methods
        result = []
        begin
          @client.requests = [] if @client
          setup if respond_to?(:setup) && !@metadata_only
        rescue AssertionException => e
          @setup_failed = true
          @setup_failure_message = e.message
        rescue => f
          @setup_failed = true
          @setup_failure_message = f.message
        end
        @setup_requests = @client.requests.map(&:to_hash) if @client
        prefix = if @metadata_only then 'generating metadata' else 'executing' end
        methods = tests
        methods = tests & @tests_subset unless @tests_subset.blank?
        methods.each do |test_method|
          @client.requests = [] if @client
          FHIR.logger.info "[#{title}#{('_' + @resource_class.name.demodulize) if @resource_class}] #{prefix}: #{test_method}..."
          begin
            result << execute_test_method(test_method)
          rescue => e
            result << TestResult.new('ERROR', "Error #{prefix} #{test_method}", STATUS[:error], "#{test_method} failed, fatal error: #{e.message}", e.backtrace.join("\n")).to_hash.merge!({:test_method => test_method})
          end
        end
        begin
          @client.requests = [] if @client
          teardown if respond_to?(:teardown) && !@metadata_only
          @teardown_requests = @client.requests.map(&:to_hash) if @client
        rescue
        end
        result
      end

      def execute_test_method(test_method)
        response = self.method(test_method).call().to_hash.merge!({:test_method => test_method })
        response.merge!({:requests => @client.requests.map { |r| ( r ? r.to_hash : nil ) } }) if @client
        response
      end

      def author
        # String identifying test file author
        self.class.name
      end

      def description
        # String containing test file description
        self.class.name
      end

      def details
        {}
      end

      def id
        # String used to order test files for execution
        self.object_id.to_s
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
        methods.sort {|a, b| @@ordered_tests.index(a) <=> @@ordered_tests.index(b) }
      end

      def self.store_test_order(test_method)
        @@ordered_tests << test_method
      end

      def warning
        begin
          yield
        rescue AssertionException => e
          @warnings << e.message
        end
      end

      def ignore_client_exception
        begin
          yield
        rescue ClientException
        end
      end

      def mute_response_body(reason = '', &block)
        return if @client.nil? || !block_given?

        count_before = @client.requests.length
        yield
        @client.requests.from(count_before).each { |req| req.response[:body] = reason }

      end

    end
  end
end
