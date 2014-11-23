module Crucible
  module Tests
    class BaseTest

      include Crucible::Tests::Assertions

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title']
      STATUS = {
        pass: 'pass',
        fail: 'fail',
        error: 'error',
        skip: 'skip'
      }

      def initialize(client)
        @client = client
      end

      def execute
        [{test_name => {
            test_file: test_name,
            tests: execute_test_methods
        }}]
      end

      def execute_test_methods
        result = {}
        tests.each do |test_method|
          puts "executing: #{test_method}..."
          begin
            result[test_method] = self.method(test_method).call().to_hash
          rescue => e
            result[test_method] = TestResult.new('ERROR', "Error executing #{test_method}", STATUS[:error], "#{test_method} failed, fatal error: #{e.message}", e.backtrace.join("\n")).to_hash
          end
        end
        result
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

      def tests
        # Array of test methods within test file
        self.methods.grep(/_test$/)
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
        operation_outcome.issue.each {|issue| messages << "#{issue.severity} : #{issue.details}" }
        messages
      end

      def self.test(key, description, &block)
        test_method = "#{key} #{description} test".downcase.tr(' ', '_').to_sym
        contents = block
        wrapped = -> () do 
          description = supplement_test_description(description) if respond_to? :supplement_test_description
          begin
            instance_eval &block
            TestResult.new(key, description, STATUS[:pass], '','')
          rescue AssertionException => e
            TestResult.new(key, description, STATUS[:fail], e.message, e.data)
          rescue SkipException => e
            TestResult.new(key, description, STATUS[:skip], "Skipped: #{test_method}", '')
          rescue => e
            TestResult.new(key, description, STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
          end
        end
        define_method test_method, wrapped
      end


    end

  end
end