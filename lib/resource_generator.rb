module Crucible
  module Tests
    class ResourceGenerator

      #
      # Generate a FHIR resource for the given class `klass`
      # If `embedded` is greater than zero, all embedded children will also
      # be generated.
      #
      def self.generate(klass,embedded=0)
        resource = klass.new
        Time.zone = 'UTC'
        set_fields!(resource)
        if(embedded > 0)
          generate_children!(resource,embedded)
        end
        resource.xmlId=nil if resource.respond_to?(:xmlId=)
        resource.versionId=nil if resource.respond_to?(:versionId=)
        resource.version=nil if resource.respond_to?(:version=)
        resource
      end

      #
      # Set the fields of this resource to have some random values.
      #
      def self.set_fields!(resource)
        fields = resource.fields
        fields.each do |key,value|
          type = value.options[:type]
		      next if key=='id' || key=='xmlId'
          # FIXME: Remove below once dateTime fields are fixed in DSTU2 models
          next if ['scheduledTime', 'time', 'effectiveTime', 'authoringTime', 'receivedTime'].include? key
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
          elsif type == Float
            gen = SecureRandom.random_number
          elsif type == Mongoid::Boolean
            gen = (SecureRandom.random_number(100) % 2 == 0)
          elsif type == FHIR::PartialDateTime
            gen = FHIR::PartialDateTime.new(Time.zone.now,Time.zone)
          elsif type == DateTime
            gen = Time.zone.now
          elsif type == BSON::Binary
            # gen = SecureRandom.random_bytes
            gen = SecureRandom.base64
          elsif type == BSON::ObjectId or type == Array or type == Object or type == FHIR::AnyType
            gen = nil # ignore
          # else
          #   puts "Unabled to generate field #{key} for #{resource.class} -- unrecognized type: #{type}"
          end
          # TODO: Improve field value generation for coded fields
          gen = gen[0..19] if key == 'language'
          resource[key] = gen if !gen.nil?
        end
        resource
      end


      #
      # Generate children for this resource.
      #
      def self.generate_children!(resource,embedded=0)
        children = resource.embedded_relations
        children.each do |key,value|
          # TODO: Determine if we can generate references or meta information
          next if ['meta'].include? key
          # TODO: Ignore references if we don't exlpicitly require them
          # next if value[:class_name] == 'FHIR::Reference'
          klass = resource.get_fhir_class_from_resource_type(value[:class_name])
          child = generate(klass,(embedded-1)) if(value[:class_name] != 'FHIR::Extension')
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
