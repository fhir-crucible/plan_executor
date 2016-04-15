module Crucible
  module Tests
    class BaseSuite < BaseTest

      EXCLUDED_RESOURCES = ['DomainResource', 'Parameters', 'GuidanceResponse', 'ModuleDefinition', 'OperationOutcome']

      def title
        self.class.name.demodulize
      end

      def parse_operation_outcome(body)
        # body should be a String
        outcome = nil
        begin
          outcome = FHIR::Resource.from_contents(body)
          outcome = nil if outcome.class!=FHIR::OperationOutcome
        rescue
          outcome = nil
        end
        outcome
      end

      def build_messages(operation_outcome)
        messages = []
        if !operation_outcome.nil? and !operation_outcome.issue.nil?
          operation_outcome.issue.each {|issue| messages << "#{issue.severity}: #{issue.code}: #{issue.details.try(:text) || issue.diagnostics}" }
        end
        messages
      end

      def self.fhir_resources
        FHIR::RESOURCES.select {|r| !EXCLUDED_RESOURCES.include?(r)}.map {|r| "FHIR::#{r}".constantize}
      end

      def requires(hash)
        @requires << hash
      end

      def validates(hash)
        @validates << hash
      end

      def links(url)
        @links << url
      end

      def collect_metadata(methods_only=false)
        @metadata_only = true
        if @resource_class
          result = execute(@resource_class)
        else
          result = execute
        end
        result = result.values.first if methods_only
        @metadata_only = false
        result
      end

      def metadata(&block)
        yield
        skip if @setup_failed
        skip if @metadata_only
      end

      def self.test(key, desc, &block)
        test_method = "#{key} #{desc} test".downcase.tr(' ', '_').to_sym
        contents = block
        wrapped = -> () do
          @warnings, @links, @requires, @validates = [],[],[],[]
          description = nil
          if respond_to? :supplement_test_description
            description = supplement_test_description(desc)
          else
            description = desc
          end
          result = TestResult.new(key, description, STATUS[:pass], '','')
          begin
            t = instance_eval &block
            result.update(t.status, t.message, t.data) if !t.nil? && t.is_a?(Crucible::Tests::TestResult)
          rescue AssertionException => e
            result.update(STATUS[:fail], e.message, e.data)
          rescue SkipException => e
            result.update(STATUS[:skip], "Skipped: #{test_method}", '')
          rescue => e
            result.update(STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
          end
          result.update(STATUS[:skip], "Skipped because setup failed.", "-") if @setup_failed
          result.warnings = @warnings unless @warnings.empty?
          result.requires = @requires unless @requires.empty?
          result.validates = @validates unless @validates.empty?
          result.links = @links unless @links.empty?
          result.id = key
          result.code = contents.source
          result.id = "#{result.id}_#{result_id_suffix}" if respond_to? :result_id_suffix # add the resource to resource based tests to make ids unique

          result
        end
        define_method test_method, wrapped
      end

      def resource_category(resource)
        unless @resource_category
          @categories_by_resource = {}
          fhir_structure = Crucible::FHIRStructure.get
          categories = fhir_structure['children'].select {|n| n['name'] == 'RESOURCES'}.first['children']
          pull_children = lambda {|n, chain| n['children'].nil? ? n['name'] : n['children'].map {|child| chain.call(child, chain)}}
          categories.each do |category|
            pull_children.call(category, pull_children).flatten.each do |resource_name|
              @categories_by_resource[resource_name] = category['name']
            end
          end
        end
        @categories_by_resource[resource.underscore.humanize.downcase] || 'Uncategorized'
      end

    end
  end
end
