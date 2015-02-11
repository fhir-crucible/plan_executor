module Crucible
  module Tests
    class TestScriptEngine

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
        @scripts = Crucible::Generator::Resources.new.testscripts.map {|ts| BaseTestScript.new(ts) }
      end

      def list_all_with_conformance(multiserver=false, metadata=nil)
      	{}
      end

      def tests
        @scripts || []
      end

      def find_test(key)
        @scripts.find{|s| s.id == key} || []
      end

      def self.list_all
        list = {}
        # TODO: Determine if we need resource-based testscript listing support
        TestScriptEngine.new.tests.each do |test|
          list[test.title] = {}
          BaseTest::JSON_FIELDS.each {|field| list[test.title][field] = test.send(field)}
        end
        list
      end

    end
  end
end
