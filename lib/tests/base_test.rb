module Crucible
  module Tests
    class BaseTest

      def initialize(client)
        @client = client
      end

      def execute
        self.methods.grep(/_test$/).each do |test_method|
          puts "executing: #{test_method}..."
          self.method(test_method).call()
        end
      end

      def description
        self.class.name
      end

      def author
        self.class.name
      end

      def title
        self.class.name.split('::').last
      end

      def tests
        self.methods.grep(/_test$/)
      end

      # timestamp?

    end
  end
end