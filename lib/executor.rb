module Crucible
  module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute_all
        results = {}
        Crucible::Tests.constants.grep(/Test$/).each do |test|
          next if test == :BaseTest
          results[test] = {
            test_file: test,
            tests: Crucible::Tests.const_get(test).new(@client).execute
          }
        end
        if !Dir.exists?('./results')
          Dir.mkdir('./results')
        end
        json = JSON.pretty_unparse(results)
        File.open("./results/execute_all.json","w") {|f| f.write json }
        results
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
