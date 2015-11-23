module Crucible
  module Tests
    class Executor

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
        @suite_engine = SuiteEngine.new(@client, @client2)
        #@testscript_engine = TestScriptEngine.new(@client, @client2)
      end

      def execute(test)
        test.execute
      end

      def execute_all
        results = {}
        self.tests.each do |test|
          # TODO: Do we want to separate out multiserver tests?
          next if test.multiserver
          results.merge! execute(test)
        end
        results
      end

      def self.list_all(multiserver=false, metadata=false)
        list = SuiteEngine.list_all(metadata) #.merge TestScriptEngine.list_all(metadata)
        list.select {|key,value| value['multiserver'] == multiserver}
      end

      def tests
        tests = @suite_engine.tests#.concat @testscript_engine.tests
        tests.sort{|t1,t2| t1.id <=> t2.id }
      end

      # finds a test by class name for suites, and by filename for testscript
      def find_test(key)
        @suite_engine.find_test(key) #|| @testscript_engine.find_test(key)
      end

      # finds a test from the given key and extracts only metadata into a hash
      def extract_metadata_from_test(key)
        test = find_test(key)
        test_metadata = test.collect_metadata(true)
        extracted_metadata = {}
        BaseTest::METADATA_FIELDS.each do |field|
          field_hash = {}
          test_metadata.each { |tm| field_hash[tm[:test_method]] = tm[field] }
          extracted_metadata[field] = field_hash
        end
        extracted_metadata
      end

    end
  end
end
