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
            content = self.method(test_method).call()
            status = 'passed'
          rescue => e
            content = "#{test_method} failed. Error: #{e.message}."
            if e.message.include? 'Implementation missing'
              status = 'missing'
            else
              status = 'failed'
            end
          end
          result[test_method] = {
            test_method: test_method,
            status: status,
            result: content
          }
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

    end
  end
end