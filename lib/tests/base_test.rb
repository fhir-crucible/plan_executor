module Crucible
  module Tests
    class BaseTest

      include Crucible::Tests::Assertions

      BASE_SPEC_LINK = 'http://hl7.org/fhir/2016May'
      REST_SPEC_LINK = "#{BASE_SPEC_LINK}/http.html"

      attr_accessor :tests_subset
      attr_accessor :tags
      attr_accessor :category
      attr_accessor :warnings

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title', 'multiserver', 'tags', 'details', 'category']
      STATUS = {
        pass: 'pass',
        fail: 'fail',
        error: 'error',
        skip: 'skip'
      }
      METADATA_FIELDS = ['links', 'requires', 'validates']

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
        @client.monitor_requests if @client
        @client2.monitor_requests if @client2
        @tags ||= []
        FHIR::Model.client = client
        @warnings = []
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
          setup if respond_to? :setup and not @metadata_only
        rescue AssertionException => e
          @setup_failed = e
        end
        prefix = if @metadata_only then 'generating metadata' else 'executing' end
        methods = tests
        methods = tests & @tests_subset unless @tests_subset.blank?
        methods.each do |test_method|
          @client.requests = [] if @client
          puts "[#{title}#{('_' + @resource_class.name.demodulize) if @resource_class}] #{prefix}: #{test_method}..."
          begin
            result << execute_test_method(test_method)
          rescue => e
            result << TestResult.new('ERROR', "Error #{prefix} #{test_method}", STATUS[:error], "#{test_method} failed, fatal error: #{e.message}", e.backtrace.join("\n")).to_hash.merge!({:test_method => test_method})
          end
        end
        begin
          teardown if respond_to? :teardown and not @metadata_only
        rescue
        end
        result
      end

      def execute_test_method(test_method)
        response = self.method(test_method).call().to_hash.merge!({:test_method => test_method })
        response.merge!({:requests => @client.requests.map { |r| r.to_hash } }) if @client
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
        methods
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

    end
  end
end
