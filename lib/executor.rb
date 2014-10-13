module Crucible
	module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute_all
        Crucible::Tests.constants.grep(/Test$/).each do |test|
          Crucible::Tests.const_get(test).new(@client).execute
        end
      end

      def self.list_all
        list = {}
        Crucible::Tests.constants.grep(/Test$/).each do |test|
          next if test == :BaseTest
          test_file = Crucible::Tests.const_get(test).new(nil)
          list[test] = {
            author: test_file.author,
            description: test_file.description,
            title: test_file.title,
            tests: test_file.tests
          }
        end
        list
      end

    end
  end
end
