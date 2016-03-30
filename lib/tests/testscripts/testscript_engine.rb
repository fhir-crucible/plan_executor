module Crucible
  module Tests
    class TestScriptEngine

      @@scripts = nil

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
      end

      def tests
        @@scripts || []
      end

      def find_test(key)
        @@scripts.find{|s| s.id == key || s.title == key} || []
      end

      def execute_all
        results = {}
        self.tests.each do |test|
          # TODO: Do we want to separate out multiserver tests?
          next if test.multiserver
          results.merge! test.execute
        end
        results
      end

      def self.list_all(metadata=false)
        list = {}
        # TODO: Determine if we need resource-based testscript listing support
        TestScriptEngine.new.tests.each do |test|
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
        list
      end

      def self.load_testscripts
        puts ">>> Loading Testscripts"
        return if @@scripts
        # get all TestScript's in testscripts/xml
        @@scripts = []
        root = File.expand_path '.', File.dirname(File.absolute_path(__FILE__))
        files = File.join(root, 'xml', '**/*.xml')
        Dir.glob(files).each do |f|
          next if f.include? "/_reference/" # to support connectathon11 fixtures; review if there is a better way
          next if f.include? "Track11-SDC" # uses STU3 models
          next if f.include? "Track3-CDS-on-FHIR" # uses STU3 models
          next if f.include? "Track9-Patch" # uses Patch
          next if f.include? "Track6-FHIR-Genomics" # uses STU3 models

          #TODO: these can be finished with DSTU2
          next if f.include? "Track2-Terminology"
          next if f.include? "Track7-LabOrderLabReport"

          @@scripts << BaseTestScript.new( FHIR::TestScript.from_xml( File.read(f) ), @client, @client2 )
        end
        @@scripts
      end

    end
  end
end
Crucible::Tests::TestScriptEngine.load_testscripts