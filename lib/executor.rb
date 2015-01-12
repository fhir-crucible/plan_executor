module Crucible
  module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute(test)
        Crucible::Tests.const_get(test).new(@client).execute
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
        require 'builder'
        Dir.mkdir('./ctl') unless Dir.exists?('./ctl')

        self.tests.each do |test|
          test_file = Crucible::Tests.const_get(test).new(nil)

          metadata = test_file.collect_metadata()
          for test_suite in metadata
            suite_name = test_suite.keys.first
            file = File.open("./ctl/#{suite_name}.ctl", "w")
            xml = Builder::XmlMarkup.new(:indent => 2, target: file)
            xml.instruct!
            xml.ctl :suite, {name: "#{suite_name}"} do
              xml.ctl :title, suite_name
              xml.ctl :"starting-test", "#{suite_name}:base_test"
            end

            xml.ctl :test, {name: "#{suite_name}::base_test"} do
              xml.ctl :assertion, "base main"
              xml.ctl :code do
                (test_suite[suite_name][:tests]||[]).each {|test| xml.ctl :"call-test", "#{suite_name}::#{test[:test_method]}"}
              end
            end

            for test in test_suite[suite_name][:tests]
              xml.ctl :test, {name: "#{suite_name}::#{test[:test_method]}"} do
                xml.ctl :code, "\n#{test["code"]}\n"
                xml.ctl :context, test["description"]
                (test["links"]||[]).each {|link| xml.ctl :link, link}
                xml.ctl :assertion, (test["validates"]||[]).map {|a| "Validates the #{(a[:methods].join(",")).upcase} methods on #{a[:resource]}"}.join("/n")
              end
            end
            file.close
          end
        end

          #   test_file = Crucible::Tests.const_get(test).new(nil)
          #   if test_file.respond_to? 'resource_class='
          #     @fhir_classes.each do |klass|
          #       if !klass.included_modules.find_index(FHIR::Resource).nil?
          #         file = File.open("./ctl/#{test_file.send("title")}-#{klass.name.demodulize}", "w")
          #         xml = Builder::XmlMarkup.new(:indent => 2, target: file)
          #         xml.instruct!
          #         test_file.resource_class = klass
          #         xml.ctl :suite, {name: "#{test_file.send("title")}::#{klass.name.demodulize}"} do
          #           xml.ctl :title, "#{test_file.send("title")}::#{klass.name.demodulize}"
          #           xml.ctl :description,  test_file.send("description")
          #
          #         end
          #         test_file.send("tests").each do |test_function|
          #           xml.ctl :test, {name: "#{test}::#{klass.name.demodulize}::#{test_function}"} do
          #             test_data = test_file.send(test_function)
          #             (test_data.links||[]).each {|link| xml.ctl :link, link}
          #             xml.ctl :code, test_file.method(test_function).source
          #           end
          #         end
          #         file.close
          #         # xml.target!
          #       end
          #     end
          #   end
          #   file = File.open("./ctl/#{test_file.send("title")}", "w")
          #   xml = Builder::XmlMarkup.new(:indent => 2, target: file)
          #   xml.instruct!
          #   xml.ctl :suite, {name: test} do
          #     xml.ctl :title, test_file.send("title")
          #     xml.ctl :description, test_file.send("description")
          #   end
          #   test_file.send("tests").each do |test_function|
          #     xml.ctl :test, {name: "#{test}::#{test_function}"} do
          #       test_data = test_file.send(test_function)
          #       (test_data.links||[]).each {|link| xml.ctl :link, link}
          #     end
          #   end
          #   file.close
          #   # xml.target!
          # end


      end

      def self.list_all
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
        list
      end

      def self.tests
        # sort test files by defined id field
        Crucible::Tests.constants.grep(/Test$/).sort{|t1,t2| Crucible::Tests.const_get(t1).new(nil).id <=> Crucible::Tests.const_get(t2).new(nil).id } - [:BaseTest]
      end

    end
  end
end
