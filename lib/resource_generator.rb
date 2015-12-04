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
        resource.text=nil if [FHIR::Bundle,FHIR::Binary,FHIR::Parameters].include?(klass)
        resource
      end

      #
      # Set the fields of this resource to have some random values.
      #
      def self.set_fields!(resource)
        # Organize some of the validators
        validators = {}
        resource.class.validators.collect{|v| v if v.class==Mongoid::Validatable::FormatValidator}.compact.each do |v|
          v.attributes.each{|a| validators[a] = v.options[:with]}
        end

        # For now, we'll skip fields that can have multiple datatypes, such as attribute[x]
        multiples = []
        if resource.class.constants.include? :MULTIPLE_TYPES
          multiples = resource.class::MULTIPLE_TYPES.map{|k,v| v}.flatten
        end

        # Get valid codes
        valid_codes = {}
        if resource.class.constants.include? :VALID_CODES
          valid_codes = resource.class::VALID_CODES
        end

        # Get special codes
        special_codes = {}
        if resource.class.constants.include? :SPECIAL_CODES
          special_codes = resource.class::SPECIAL_CODES
        end

        fields = resource.fields
        fields.each do |key,value|
          type = value.options[:type]
		      next if ['id','xmlId','version','versionId','implicitRules'].include? key
          next if multiples.include? key
          gen = nil
          if type == String
            gen = SecureRandom.base64
            if valid_codes[key.to_sym]
              valid_values = valid_codes[key.to_sym]
              if !valid_values.nil?
                gen = valid_values[ SecureRandom.random_number( valid_values.length ) ]
              end
            elsif validators[key.to_sym]
              date = DateTime.now
              regex = validators[key.to_sym]
              if date.strftime("%Y-%m-%dT%T.%LZ").match(regex)
                gen = date.strftime("%Y-%m-%dT%T.%LZ")
              elsif date.strftime("%Y-%m-%d").match(regex)
                gen = date.strftime("%Y-%m-%d")
              elsif date.strftime("%T").match(regex)
                gen = date.strftime("%T")
              end
            elsif special_codes[key.to_sym]
              if special_codes[key.to_sym]=='MimeType'
                gen = 'text/plain'
              elsif special_codes[key.to_sym]=='Language'
                gen = 'en-US'
              end
            end
          elsif type == Integer
            gen = SecureRandom.random_number(100)
          elsif type == Float
            gen = SecureRandom.random_number
            while gen.to_s.match(/e/) # according to FHIR spec: decimals may not contain exponents
              gen = SecureRandom.random_number
            end
          elsif type == Mongoid::Boolean
            gen = (SecureRandom.random_number(100) % 2 == 0)
          elsif type == BSON::Binary
            # gen = SecureRandom.random_bytes
            gen = SecureRandom.base64
          elsif type == BSON::ObjectId or type == Array or type == Object or type == FHIR::AnyType
            gen = nil # ignore
          # else
          #   puts "Unable to generate field #{key} for #{resource.class} -- unrecognized type: #{type}"
          end
          gen='en-US' if(key=='language' && type==String)
          resource[key] = gen if !gen.nil?
        end
        resource
      end


      #
      # Generate children for this resource.
      #
      def self.generate_children!(resource,embedded=0)
        # For now, we'll skip fields that can have multiple datatypes, such as attribute[x]
        multiples = []
        if resource.class.constants.include? :MULTIPLE_TYPES
          multiples = resource.class::MULTIPLE_TYPES.map{|k,v| v}.flatten
        end

        children = resource.embedded_relations
        children.each do |key,value|
          # TODO: Determine if we can generate references or meta information
          next if ['meta'].include? key
          next if multiples.include? key
          
          klass = resource.get_fhir_class_from_resource_type(value[:class_name])
          case klass
          when FHIR::Reference
            child = FHIR::Reference.new
            child.display = "#{key} #{SecureRandom.base64}"
          when FHIR::CodeableConcept
            child = FHIR::CodeableConcept.new
            child.text = "#{key} #{SecureRandom.base64}"
          when FHIR::Coding
            child = FHIR::Coding.new
            child.display = "#{key} #{SecureRandom.base64}"
          when FHIR::Quantity
            child = FHIR::Quantity.new
            child.value = SecureRandom.random_number
            child.unit = SecureRandom.base64
          else
            child = generate(klass,(embedded-1)) if(!['FHIR::Extension','FHIR::PrimitiveExtension','FHIR::Signature'].include?(value[:class_name]))
          end

          case klass
          when FHIR::Identifier
            child.system = nil
          when FHIR::Attachment
            child.url = nil
          end

          if value[:relation] == Mongoid::Relations::Embedded::Many
            child = ([] << child) if child
          end
          resource[key] = child if child
        end
        resource
      end

      def self.minimal_patient(identifier='0',name='Name')
        resource = FHIR::Patient.new
        resource.identifier = [ minimal_identifier(identifier) ]
        resource.name = [ minimal_humanname(name) ]
        resource
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      # units: must be UCOM
      def self.minimal_observation(system='http://loinc.org',code='8302-2',value=170,units='cm',patientId=nil)
        resource = FHIR::Observation.new
        resource.status = 'final'
        resource.code = minimal_codeableconcept(system,code)
        if patientId
          ref = FHIR::Reference.new
          ref.reference = "Patient/#{patientId}"
          resource.subject = ref
        end
        resource.valueQuantity = minimal_quantity(value,units)
        resource
      end

      # Default system/code are for SNOMED "Obese (finding)"
      def self.minimal_condition(system='http://snomed.info/sct',code='414915002',patientId=nil)
        resource = FHIR::Condition.new
        resource.patient = FHIR::Reference.new
        if patientId
          resource.patient.reference = "Patient/#{patientId}"
        else
          resource.patient.display = 'Patient'
        end
        resource.code = minimal_codeableconcept(system,code)
        resource.verificationStatus = 'confirmed'
        resource
      end

      def self.minimal_identifier(identifier='0')
        mid = FHIR::Identifier.new
        mid.use = 'official'
        mid.system = 'http://projectcrucible.org'
        mid.value = identifier
        mid
      end

      def self.minimal_humanname(name='Name')
        hn = FHIR::HumanName.new
        hn.use = 'official'
        hn.family = [ 'Crucible' ]
        hn.given = [ name ]
        hn.text = "#{hn.given[0]} #{hn.family[0]}"
        hn
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      def self.minimal_codeableconcept(system='http://loinc.org',code='8302-2')
        concept = FHIR::CodeableConcept.new
        concept.coding = [ minimal_coding(system,code) ]
        concept
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      def self.minimal_coding(system='http://loinc.org',code='8302-2')
        coding = FHIR::Coding.new
        coding.system = system
        coding.code = code
        coding
      end

      def self.minimal_quantity(value=170,units='cm')
        quantity = FHIR::Quantity.new
        quantity.value = value
        quantity.unit = units
        quantity.system = 'http://unitsofmeasure.org'
        quantity
      end

      def self.minimal_animal
        animal = FHIR::Patient::AnimalComponent.new
        animal.species = minimal_codeableconcept('http://hl7.org/fhir/animal-species','canislf') # dog
        animal.breed = minimal_codeableconcept('http://hl7.org/fhir/animal-breed','gret') # golden retriever
        animal.genderStatus = minimal_codeableconcept('http://hl7.org/fhir/animal-genderstatus','intact') # intact
        animal
      end

    end
  end
end
