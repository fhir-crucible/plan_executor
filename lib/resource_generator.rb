module Crucible
  module Tests
    class ResourceGenerator

      #
      # Generate a FHIR resource for the given class `klass`
      # If `embedded` is true, all embedded children will also
      # be generated.
      #
      def self.generate(klass,embedded)
        resource = klass.new
        set_fields!(resource)
        if embedded
          generate_children!(resource)
        end
        resource
      end

      # 
      # Set the fields of this resource to have some random values.
      #
      def self.set_fields!(resource)
        fields = resource.fields
        fields.each do |key,value|
          type = value.options[:type]
          gen = nil
          if type == String
            gen = SecureRandom.urlsafe_base64

            if resource.class.constants.include? :VALID_CODES
              valid_values = resource.class::VALID_CODES[key.to_sym]
              if !valid_values.nil?
                gen = valid_values[ SecureRandom.random_number( valid_values.length ) ]
              end
            end

          elsif type == Integer
            gen = SecureRandom.random_number(100)
          elsif type == Boolean
            gen = (SecureRandom.random_number(100) % 2 == 0)
          #else
          #  puts "Unabled to generate field #{key} for #{resource.class} -- unrecognized type: #{type}"
          end
          resource[key] = gen if gen
        end
        resource
      end


      # 
      # Generate children for this resource.
      #
      def self.generate_children!(resource)
        children = resource.embedded_relations
        children.each do |key,value|
          klass = resource.get_fhir_class_from_resource_type(value[:class_name])
          child = generate(klass,false)
          if value[:relation] == Mongoid::Relations::Embedded::Many
            child = ([] << child) if child
          end
          resource[key] = child if child
        end
        resource
      end

    end
  end
end
