module Crucible
  module Tests
    class Executor

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
        @suite_engine = Crucible::Tests::SuiteEngine.new(@client, @client2)
        @testscript_engine = Crucible::Tests::TestScriptEngine.new(@client, @client2)
      end

      def execute(test)
        test.execute
      end

      def execute_all
        Executor.tests.each do |test|
          results = results.concat execute(test)
        end
      end

      def list_all_with_conformance(multiserver=false, metadata=nil)
        @suite_engine.list_all_with_conformance(multiserver, metadata).merge @testscript_engine.list_all_with_conformance(multiserver, metadata)
      end

      def self.list_all(multiserver=false)
        list = Crucible::Tests::SuiteEngine.list_all.merge Crucible::Tests::TestScriptEngine.list_all
        list.select {|key,value| value['multiserver'] == multiserver}
      end

      def self.tests
        tests = Crucible::Tests::SuiteEngine.tests.concat Crucible::Tests::TestScriptEngine.tests
        tests.sort{|t1,t2| t1.id <=> t2.id }
      end

    end
  end
end
