module Crucible
  module Tests
    class BaseSuite < BaseTest

      EXCLUDED_RESOURCES = ['DomainResource', 'Resource', 'Parameters', 'OperationOutcome']

      def title
        self.class.name.demodulize
      end

      def parse_operation_outcome(body)
        # body should be a String
        outcome = nil
        begin
          outcome = FHIR.from_contents(body)
          outcome = nil if outcome.class!=FHIR::OperationOutcome
        rescue
          outcome = nil
        end
        outcome
      end

      def build_messages(operation_outcome)
        messages = []
        if !operation_outcome.nil? && !operation_outcome.issue.nil?
          operation_outcome.issue.each {|issue| messages << "#{issue.severity}: #{issue.code}: #{issue.details.try(:text) || issue.diagnostics}" }
        end
        messages
      end

      # helpers to grab the versioned resources
      # move to another area?

      def fhir_version
        @client.fhir_version
      end

      def get_resource(resource)
        self.class.get_resource(@client.fhir_version, resource)
      end

      def fhir_resources
        self.class.fhir_resources(@client.fhir_version)
      end

      def resource_from_contents(body)
        if @client.fhir_version.to_s.upcase == 'DSTU2'
          FHIR::DSTU2.from_contents(body)
        else
          FHIR.from_contents(body)
        end
      end

      def version_namespace
        if @client.fhir_version.to_s.upcase == 'DSTU2'
          "FHIR::DSTU2".constantize
        else
          "FHIR".constantize
        end
      end

      def self.get_resource(fhir_version, resource)
        if fhir_version.to_s.upcase == 'DSTU2'
          "FHIR::DSTU2::#{resource}".constantize
        else
          "FHIR::#{resource}".constantize
        end

      end


      def self.valid_resource?(fhir_version, resource)
        if fhir_version.to_s.upcase == 'DSTU2'
          FHIR::DSTU2::RESOURCES.include?(resource)
        else
          FHIR::RESOURCES.include?(resource)
        end
      end

      def self.fhir_resources(fhir_version=nil)

        resources = FHIR::RESOURCES
        namespace = 'FHIR'
        if !fhir_version.nil? && FHIR.constants.include?(fhir_version.upcase)
          resources = FHIR.const_get(fhir_version.upcase)::RESOURCES
          namespace = "FHIR::#{fhir_version.to_s.upcase}"
        end

        resources.select {|r| !EXCLUDED_RESOURCES.include?(r)}.map {|r| "#{namespace}::#{r}".constantize}
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
            result.update(STATUS[:skip], "Skipped: #{e.message}", '')
          rescue ClientException => e
            result.update(STATUS[:fail], e.message, '')
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
