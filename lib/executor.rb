module Crucible
  module Tests
    class Executor

      def initialize(client)
        @client = client
        @fhir_classes = Mongoid.models.select {|c| c.name.include? 'FHIR'}
      end

      def execute_all
        results = {}
        self.class.tests.each do |test|
          t = Crucible::Tests.const_get(test).new(@client)
          #if t can set class
          if t.respond_to? 'resource_class='
            @fhir_classes.each do | klass |
              # hack to ignore embedded subclasses
              if klass.to_s.split('::').size == 2
                t.resource_class = klass
                results["#{test}#{klass.name.demodulize}"] = {
                  test_file: test,
                  tests: t.execute
                }              
              end
            end
          else
            results[test] = {
              test_file: test,
              tests: t.execute
            }
          end
        end
        Dir.mkdir('./results') unless Dir.exists?('./results')
        json = JSON.pretty_unparse(results)
        File.open("./results/execute_all.json","w") {|f| f.write json }
        results
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
              # hack to ignore embedded subclasses
              if klass.to_s.split('::').size == 2
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
