module FHIR

  class Client

    attr_reader :requirements

    def record_requirement(operation, *args)
      if (args && args.is_a?(Array))
        @requirements ||= []
        resource = args[0]
        resource = resource.class unless resource.is_a? Class
        @requirements << {resource: resource, methods: [operation]}
      end
    end

    def clear_requirements
      @requirements = []
    end

    def monitor_requirements
      return if @decorated
      @decorated = true
      FHIR::Sections.constants.each do |mod|
        FHIR::Sections.const_get(mod).instance_methods.each do |m|
          m = m.to_sym
          class_eval %Q{
            alias #{m}_original #{m}
            def #{m}(*args, &block)
              record_requirement('#{m}', *args)
              #{m}_original(*args, &block)
            end
          }
        end
      end

  end

  end
end