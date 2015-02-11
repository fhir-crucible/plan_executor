module Crucible
  module Tests
    class TestScriptEngine

      # map base_test methods to testscript methods
      TESTSCRIPT_JSON_FIELDS = {
        'author' => 'name', # might not have a field for this yet
        'description' => 'description',
        'id' => 'xmlId',
        'tests' => 'tests',
        'title' => 'name',
        'multiserver' => 'multiserver' # might not have a flag for this yet
        }

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
        @scripts = Crucible::Generator::Resources.new.testscripts(self)
      end

      def list_all_with_conformance(multiserver=false, metadata=nil)
      	{}
      end

      def tests
        @scripts || []
      end

      def find_test(key)
        @scripts.find{|s| s.xmlId == key} || []
      end

      def self.list_all
        list = {}
        fields = Crucible::Tests::BaseTest::JSON_FIELDS
        # TODO: Determine if we need resource-based testscript listing support
        TestScriptEngine.new(nil).tests.each do |test|
          list[test.name] = {}
          fields.each {|field| list[test.name][field] = test.send(TESTSCRIPT_JSON_FIELDS[field])}
        end
        list
      end

    end
  end
end
