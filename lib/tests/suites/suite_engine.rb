module Crucible
  module Tests
    class SuiteEngine

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
        build_suites_map
      end

      def metadata(test)
        Crucible::Tests.const_get(test).new(@client).collect_metadata
      end

      def metadata_all
        results = []
        tests.each do |test|
          results = results.concat metadata(test)
        end
        results
      end

      def self.list_all(metadata=false)
        list = {}
        # FIXME: Organize defaults between instance & class methods
        SuiteEngine.new.tests.each do |test|
          test_class = test.class.name.demodulize
          #if t can set class
          if test.respond_to? 'resource_class='
            [:dstu2, :stu3].each do |fhir_version|
              Crucible::Tests::BaseSuite.fhir_resources(fhir_version).each do |klass|
                klass_name = klass.name.demodulize
                test_name = "#{test_class}#{klass_name}"
                test.resource_class = klass 
                list[test_name] = {} unless list.include?(test_name)
                BaseTest::JSON_FIELDS.each {|field| list[test_name][field] = test.send(field) unless field == 'supported_versions'} #supported versions overwritten
                list[test_name]['supported_versions'] = [] if list[test_name]['supported_versions'].nil?
                list[test_name]['supported_versions'] << fhir_version 
                list[test_name]['resource_class'] = klass # this currently just gets the stu3 version, problem?
                if metadata
                  test_metadata = test.collect_metadata(true)
                  BaseTest::METADATA_FIELDS.each do |field|
                    field_hash = {}
                    test_metadata.each { |tm| field_hash[tm[:test_method]] = tm[field] }
                    list[test_name][field] = field_hash
                  end
                end
              end
            end
          else
            list[test.title] = {}
            BaseTest::JSON_FIELDS.each {|field| list[test.title][field] = test.send(field)}
            if metadata
              test_metadata = test.collect_metadata(true)
              BaseTest::METADATA_FIELDS.each do |field|
                field_hash = {}
                test_metadata.each { |tm| field_hash[tm[:test_method]] = tm[field] }
                list[test.title][field] = field_hash
              end
            end
          end
        end
        list
      end

      # Build all the test suites if none exist, but only reference the class
      def tests
        # return newly-initialized copies of the tests
        @suites.values.map {|suite| suite.new(@client, @client2)}
      end

      # Use the built test suites to find a given test suite
      def find_test(key)
        @suites[key.to_sym].new(@client, @client2) if @suites.keys.include?(key.to_sym)
      end

      def build_suites_map
        @suites = {}
        (Crucible::Tests.constants.grep(/Test$/) - [:BaseTest]).each do |suite|
          @suites[suite] = Crucible::Tests.const_get(suite)
        end
      end

      def self.generate_metadata
        metadata = {}
        puts "---"
        puts "BUILDING METADATA"
        puts "---"
        SuiteEngine.new.tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)
          if test_file.respond_to? 'resource_class='
            Crucible::Tests::BaseSuite.fhir_resources.each do |klass|
              test_file.resource_class = Module.const_get("FHIR::#{klass}")
              puts "---"
              puts "BUILDING METADATA - #{test}#{klass}"
              puts "---"
              metadata["#{test}#{klass}"] = test_file.collect_metadata(true)
            end
          else
            puts "---"
            puts "BUILDING METADATA - #{test}"
            puts "---"
            metadata[test] = test_file.collect_metadata(true)
          end
        end
        puts "---"
        puts "FINISHED METADATA"
        puts "---"
        metadata
      end

    end
  end
end
