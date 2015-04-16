module Crucible
  module Tests
    class SuiteEngine

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
        @suites = {}
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

      def list_all_with_conformance(multiserver=false, metadata=nil)
        list = {}
        @fhir_classes ||= Mongoid.models.select {|c| c.name.include? 'FHIR'}
        conf = @client.conformanceStatement
        conformance_resources = Hash[conf.rest[0].resource.map{ |r| [r.fhirType, r.interaction.map(&:code)]}] if conf
        if multiserver
          conf2 = @client2.conformanceStatement
          conformance1_resources = conformance_resources
          conformance2_resources = Hash[conf2.rest[0].resource.map{ |r| [r.fhirType, r.interaction.map(&:code)]}] if conf2
          fhirTypes = conformance1_resources.keys & conformance2_resources.keys
          conformance_resources = {}
          fhirTypes.each do |fhirType|
            conformance_resources[fhirType] = (conformance1_resources[fhirType] || []) & (conformance2_resources[fhirType] || [])
          end
        end
        metadata ||= SuiteEngine.generate_metadata
        fields = BaseTest::JSON_FIELDS - ['tests']
        tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)
          next unless test_file.multiserver == multiserver
          #if t can set class
          if test_file.respond_to? 'resource_class='
            @fhir_classes.each do |klass|
              if !klass.included_modules.find_index(FHIR::Resource).nil?
                test_file.resource_class = klass
                list["#{test}#{klass.name.demodulize}"] = {}
                list["#{test}#{klass.name.demodulize}"]['resource_class'] = klass
                fields.each {|field| list["#{test}#{klass.name.demodulize}"][field] = test_file.send(field)}
                list["#{test}#{klass.name.demodulize}"]['tests'] = test_file.tests_by_conformance(conformance_resources, metadata["#{test}#{klass.name.demodulize}"])
              end
            end
          else
            list[test] = {}
            fields.each {|field| list[test][field] = test_file.send(field)}
            list[test]['tests'] = test_file.tests_by_conformance(conformance_resources, metadata[test])
          end
        end
        list
      end

      def self.list_all
        list = {}
        # FIXME: Organize defaults between instance & class methods
        @fhir_classes ||= Mongoid.models.select {|c| c.name.include? 'FHIR'}
        SuiteEngine.new.tests.each do |test|
          test_class = test.class.name.demodulize
          #if t can set class
          if test.respond_to? 'resource_class='
            @fhir_classes.each do |klass|
              if !klass.included_modules.find_index(FHIR::Resource).nil?
                test.resource_class = klass
                list["#{test_class}#{klass.name.demodulize}"] = {}
                list["#{test_class}#{klass.name.demodulize}"]['resource_class'] = klass
                BaseTest::JSON_FIELDS.each {|field| list["#{test_class}#{klass.name.demodulize}"][field] = test.send(field)}
              end
            end
          else
            list[test.title] = {}
            BaseTest::JSON_FIELDS.each {|field| list[test.title][field] = test.send(field)}
          end
        end
        list
      end

      # Build all the test suites if none exist, but only reference the class
      def tests
        if @suites.blank?
          (Crucible::Tests.constants.grep(/Test$/) - [:BaseTest]).each do |suite|
            @suites[suite] = Crucible::Tests.const_get(suite)
          end
        end
        # return newly-initialized copies of the tests
        @suites.values.map {|suite| suite.new(@client, @client2)}
      end

      # Use the built test suites to find a given test suite
      def find_test(key)
        @suites[key.to_sym].new(@client, @client2) if @suites.keys.include?(key.to_sym)
      end

      def self.generate_metadata
        @fhir_classes ||= Mongoid.models.select {|c| c.name.include? 'FHIR'}
        metadata = {}
        puts "---"
        puts "BUILDING METADATA"
        puts "---"
        SuiteEngine.new.tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)
          if test_file.respond_to? 'resource_class='
            @fhir_classes.each do |klass|
              if !klass.included_modules.find_index(FHIR::Resource).nil?
                test_file.resource_class = klass
                puts "---"
                puts "BUILDING METADATA - #{test}#{klass.name.demodulize}"
                puts "---"
                metadata["#{test}#{klass.name.demodulize}"] = test_file.collect_metadata(true)
              end
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
