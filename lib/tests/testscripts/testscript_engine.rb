module Crucible
  module Tests
    class TestScriptEngine

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
        load_testscripts
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

      def load_testscripts
        # get all TestScript's in testscripts/xml
        @scripts = []
        root = File.expand_path '.', File.dirname(File.absolute_path(__FILE__))
        files = File.join(root, 'xml', '*.xml')
        Dir.glob(files).each do |f|
          @scripts << BaseTestScript.new( FHIR::TestScript.from_xml( File.read(f) ), @client, @client2 )
        end
        @scripts
      end

    end
  end
end
