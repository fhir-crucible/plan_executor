module Crucible
  module Tests
    class Executor

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
      end

      def execute(test)
        # for single server tests, client two defaults to nil
        Crucible::Tests.const_get(test).new(@client, @client2).execute
      end

      def execute_all
        results = []
        Executor.tests.each do |test|
          results = results.concat execute(test)
        end
        Dir.mkdir('./results') unless Dir.exists?('./results')
        json = JSON.pretty_unparse(JSON.parse(results.to_json))
        File.open("./results/execute_all.json","w") {|f| f.write json }
        results
      end

      def metadata(test)
        Crucible::Tests.const_get(test).new(@client).collect_metadata
      end

      def metadata_all
        results = []
        Executor.tests.each do |test|
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
        metadata ||= Crucible::Tests::Executor.generate_metadata
        fields = Crucible::Tests::BaseTest::JSON_FIELDS - ['tests']
        Crucible::Tests::Executor.tests.each do |test|
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

      def self.generate_all_testscripts
        self.tests.each do |test|
          self.generate_testscript(test)
        end
      end

      def self.generate_testscript(test)
        require 'builder'
        Dir.mkdir('./testScripts') unless Dir.exists?('./testScripts')
        test_file = Crucible::Tests.const_get(test).new(nil)

        metadata = test_file.collect_metadata()
        for test_suite in metadata
          suite_name = test_suite.keys.first
          if metadata.size > 1
            klass_name = suite_name.split('_').last
            klass = test_file.resource_class.get_fhir_class_from_resource_type(klass_name)
            test_file.resource_class = klass
          end
          setup = test_file.method(:setup).source.lines.to_a[1..-2].join() if test_file.respond_to? 'setup'
          teardown = test_file.method(:teardown).source.lines.to_a[1..-2].join() if test_file.respond_to? 'teardown'
          
          testscript = FHIR::TestScript.new
          testscript.xmlId = test_file.id
          testscript.text = FHIR::Narrative.new
          testscript.text.status = 'generated'
          testscript.text.div = "Setup procedure:\n\n #{setup} \n\n Teardown procedure:\n\n #{teardown}"
          testscript.name = test_file.test_name
          testscript.description = test_file.description

          testscript.setup = FHIR::TestScript::TestScriptSetupComponent.new
          # TODO create setup operations
          testscript.teardown = FHIR::TestScript::TestScriptTeardownComponent.new
          # TODO create teardown operations

          testscript.test = []
          test_suite[suite_name][:tests].each do |test|
            t = FHIR::TestScript::TestScriptTestComponent.new
            t.xmlId = test['key']
            t.name = test[:test_method]
            t.description = test['description']
            t.metadata = FHIR::TestScript::TestScriptTestMetadataComponent.new
            # embeds_many :link, class_name:'FHIR::TestScript::TestScriptTestMetadataLinkComponent'
            if !test['links'].nil?
              t.metadata.link = []
              test['links'].each do |link|
                l = FHIR::TestScript::TestScriptTestMetadataLinkComponent.new
                l.url = link
                l.description = 'Specification Link'
                t.metadata.link << l
              end
            end
            # embeds_many :requires, class_name:'FHIR::TestScript::TestScriptTestMetadataRequiresComponent'
            if !test['requires'].nil?
              t.metadata.requires = []
              test['requires'].each do |requirement|
                r = FHIR::TestScript::TestScriptTestMetadataRequiresComponent.new
                r.fhirType = requirement[:resource]
                r.operations = requirement[:methods].join(', ')
                t.metadata.requires << r
              end
            end
            # embeds_many :validates, class_name:'FHIR::TestScript::TestScriptTestMetadataValidatesComponent'
            if !test['validates'].nil? 
              t.metadata.validates = []
              test['validates'].each do |validation| 
                v = FHIR::TestScript::TestScriptTestMetadataValidatesComponent.new
                v.fhirType = validation[:resource]
                v.operations = validation[:methods].join(', ')
                t.metadata.validates << v
              end
            end
            # TODO create test operations
            t.operation = [ FHIR::TestScript::TestScriptTestOperationComponent.new ]
            t.operation[0].fhirType = 'read'
            # TODO create test assertions
            t.assertion = [ FHIR::TestScript::TestScriptTestAssertionComponent.new ]
            t.assertion[0].fhirType = 'foo'

            testscript.test << t
          end

          file = File.open("./testScripts/#{suite_name}.xml", 'w')
          file.write( testscript.to_xml )
          file.close
        end
      end

      def self.generate_ctl
        self.tests.each do |test|
          self.generate_test_ctl(test)
        end
      end

      def self.generate_test_ctl(test)
        require 'builder'
        Dir.mkdir('./ctl') unless Dir.exists?('./ctl')
        test_file = Crucible::Tests.const_get(test).new(nil)

        metadata = test_file.collect_metadata()
        for test_suite in metadata
          suite_name = test_suite.keys.first
          setup = test_file.method(:setup).source.lines.to_a[1..-2].join() if test_file.respond_to? 'setup'
          teardown = test_file.method(:teardown).source.lines.to_a[1..-2].join() if test_file.respond_to? 'teardown'
          file = File.open("./ctl/#{suite_name}.xml", "w")
          xml = Builder::XmlMarkup.new(:indent => 2, target: file)
          xml.xs :schema, {:"xmlns:ctl" => "http://www.occamlab.com/ctl"} do
            xml.suite(name: "#{suite_name}") do
              xml.title(suite_name)
              # Because this element has a dash in the name we have to use this method to call it
              xml.tag!(:"starting-test", "#{suite_name}:base_test")
            end

            xml.test(name: "#{suite_name}::base_test") do
              xml.assertion "base main"
              xml.code do
                (test_suite[suite_name][:tests]||[]).each {|test| xml.tag!(:"call-test", "#{suite_name}::#{test[:test_method]}")}
              end
            end

            for test in test_suite[suite_name][:tests]
              xml.test(name: "#{suite_name}::#{test[:test_method]}", id: test["id"]) do
                xml.code "#{setup}\n #{test["code"].lines.to_a[1..-2].join()} \n#{teardown}".lstrip.rstrip
                xml.context test["description"]
                (test["links"]||[]).each {|link| xml.link link}
                assertions = []
                (test["validates"]||[]).map {|a| assertions << "Validates the #{(a[:methods].join(",")).upcase} methods on #{a[:resource]}"}
                (test["requires"]||[]).map {|a| assertions << "Requires the #{(a[:methods].join(",")).upcase} methods on #{a[:resource]}"}
                test["code"].scan(/assert.*?,\s["'](.*?)['"]/).map{|a| assertions << "Asserts False: #{a[0]}"}
                xml.assertion assertions.join("\n")
              end
            end
          end
          file.close
        end
      end

      def self.list_all(multiserver=false)
        list = {}
        # FIXME: Organize defaults between instance & class methods
        @fhir_classes ||= Mongoid.models.select {|c| c.name.include? 'FHIR'}
        self.tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)
          #if t can set class
          if test_file.respond_to? 'resource_class='
            @fhir_classes.each do |klass|
              if !klass.included_modules.find_index(FHIR::Resource).nil?
                test_file.resource_class = klass
                list["#{test}#{klass.name.demodulize}"] = {}
                list["#{test}#{klass.name.demodulize}"]['resource_class'] = klass
                Crucible::Tests::BaseTest::JSON_FIELDS.each {|field| list["#{test}#{klass.name.demodulize}"][field] = test_file.send(field)}
              end
            end
          else
            list[test] = {}
            Crucible::Tests::BaseTest::JSON_FIELDS.each {|field| list[test][field] = test_file.send(field)}
          end
        end
        list.select {|key,value| value['multiserver'] == multiserver}
      end

      def self.tests
        # sort test files by defined id field
        Crucible::Tests.constants.grep(/Test$/).sort{|t1,t2| Crucible::Tests.const_get(t1).new(nil).id <=> Crucible::Tests.const_get(t2).new(nil).id } - [:BaseTest]
      end

      def self.generate_metadata
        @fhir_classes ||= Mongoid.models.select {|c| c.name.include? 'FHIR'}
        metadata = {}
        puts "---"
        puts "BUILDING METADATA"
        puts "---"
        self.tests.each do |test|
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
