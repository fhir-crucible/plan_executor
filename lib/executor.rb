module Crucible
  module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute_all
        results = {}
        self.class.tests.each do |test|
          results[test] = {
            test_file: test,
            tests: Crucible::Tests.const_get(test).new(@client).execute
          }
        end
        # Dir.mkdir('./results') unless Dir.exists?('./results')
        # json = JSON.pretty_unparse(results)
        # File.open("./results/execute_all.json","w") {|f| f.write json }
        results
      end

      def self.list_all
        list = {}
        self.tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)
          list[test] = {}
          Crucible::Tests::BaseTest::JSON_FIELDS.each {|field| list[test][field] = test_file.send(field)}
        end
        list
      end

      def self.tests
        # sort test files by defined id field
        Crucible::Tests.constants.grep(/Test$/).sort{|t1,t2| Crucible::Tests.const_get(t1).new(nil).id <=> Crucible::Tests.const_get(t2).new(nil).id } - [:BaseTest]
      end

    end
  end
end
