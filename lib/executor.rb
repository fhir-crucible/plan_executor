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

    end
  end
end
