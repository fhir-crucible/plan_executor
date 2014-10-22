module Crucible
  module Tests
    class BaseTest

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title']

      def initialize(client)
        @client = client
      end

      def execute
        result = {}
        self.methods.grep(/_test$/).each do |test_method|
          puts "executing: #{test_method}..."
          begin
            test_result = self.method(test_method).call().to_hash
            #status = 'passed'
          rescue => e
            test_result = "#{test_method} failed. Fatal Error: #{e.message}."
            # if e.message.include? 'Implementation missing'
            #   status = 'missing'
            # else
            #   status = 'failed'
            # end
          end
          result[test_method] = test_result
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

    end
  end
end