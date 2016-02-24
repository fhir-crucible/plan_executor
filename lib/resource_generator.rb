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
        apply_invariants!(resource)
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
            gen = (SecureRandom.random_number(100) + 1) # add one in case this is a "positiveInt" which must be > 0
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
            while child.value.to_s.match(/e/) # according to FHIR spec: decimals may not contain exponents
              child.value = SecureRandom.random_number
            end
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

      def self.textonly_codeableconcept(text='text')
        concept = FHIR::CodeableConcept.new
        concept.text = text
        concept
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

      def self.apply_invariants!(resource)
        case resource.class
        when FHIR::Appointment
          resource.reason = minimal_codeableconcept('http://snomed.info/sct','219006') # drinker of alcohol
          resource.participant.each{|p| p.fhirType=[ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency') ] }
        when FHIR::AppointmentResponse
          resource.participantType = [ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency') ]
        when FHIR::AuditEvent
          resource.object.each do |o|
            o.query=nil
            o.name = "name #{SecureRandom.base64}" if o.name.nil?
          end
        when FHIR::Bundle
          resource.total = nil if !['searchset','history'].include?(resource.fhirType)
          resource.entry.each {|e|e.search=nil} if resource.fhirType!='searchset'
          resource.entry.each {|e|e.request=nil} if !['batch','transaction','history'].include?(resource.fhirType)
          resource.entry.each {|e|e.response=nil} if !['batch-response','transaction-response'].include?(resource.fhirType)
          head = resource.entry.first
          if !head.nil?
            if head.request.nil? && head.response.nil? && head.resource.nil?
              if resource.fhirType == 'document'
                head.resource = generate(FHIR::Composition,3)
              elsif resource.fhirType == 'message'
                head.resource = generate(FHIR::MessageHeader,3)  
              else
                head.resource = generate(FHIR::Basic,3)                              
              end
            end
            if head.resource.nil?
              head.fullUrl = nil
            else
              rid = SecureRandom.random_number(100) + 1
              head.fullUrl = "http://projectcrucible.org/fhir/#{rid}"
              head.resource.xmlId = "#{rid}"
            end
          end
        when FHIR::CarePlan
          resource.activity.each {|a| a.reference = nil if a.detail }
        when FHIR::Claim
          resource.item.each do |item|
            item.fhirType = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
            item.detail.each do |detail|
              detail.fhirType = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
              detail.subDetail.each do |sub|
                sub.fhirType = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
                sub.service = minimal_coding('http://hl7.org/fhir/ex-USCLS','1205')
              end
            end
          end
          resource.missingTeeth.each do |mt|
            mt.tooth = minimal_coding('http://hl7.org/fhir/ex-fdi','42')
          end
        when FHIR::ClaimResponse
          resource.item.each do |item|
            item.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
            item.detail.each do |detail|
              detail.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
              detail.subDetail.each do |sub|
                sub.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
              end
            end
          end
          resource.addItem.each do |addItem|
            addItem.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
            addItem.detail.each do |detail|
              detail.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
            end
          end
        when FHIR::Communication
          resource.payload = nil
        when FHIR::CommunicationRequest
          resource.payload = nil
        when FHIR::Composition
          resource.attester.each {|a| a.mode = ['professional']}
          resource.section.each do |section|
            section.emptyReason = nil
            section.section.each do |sub|
              sub.emptyReason = nil
              sub.section = nil
            end
          end
        when FHIR::ConceptMap
          if(resource.sourceUri.nil? && resource.sourceReference.nil?)
            resource.sourceReference = FHIR::Reference.new
            resource.sourceReference.display = "ValueSet #{SecureRandom.base64}" 
          end
          if(resource.targetUri.nil? && resource.targetReference.nil?)
            resource.targetReference = FHIR::Reference.new
            resource.targetReference.display = "ValueSet #{SecureRandom.base64}" 
          end
        when FHIR::Conformance
          resource.fhirVersion = 'DSTU2'
          resource.format = ['xml','json']
          if resource.kind == 'capability'
            resource.implementation = nil
          elsif resource.kind == 'requirements'
            resource.implementation = nil
            resource.software = nil
          end
          resource.messaging.each{|m| m.endpoint = nil} if resource.kind != 'instance'
        when FHIR::Contract
          resource.actor.each do |actor|
            actor.entity = FHIR::Reference.new
            actor.entity.display = "Patient #{SecureRandom.base64}" 
          end
          resource.term.each do |term|
            term.actor.each do |actor|
              actor.entity = FHIR::Reference.new
              actor.entity.display = "Organization #{SecureRandom.base64}" 
            end
            term.group.each do |group|
              group.actor.each do |actor|
                actor.entity = FHIR::Reference.new
                actor.entity.display = "Organization #{SecureRandom.base64}" 
              end
            end
          end
          resource.friendly.each do |f|
            f.contentAttachment = nil
            f.contentReference = FHIR::Reference.new
            f.contentReference.display = "DocumentReference #{SecureRandom.base64}" 
          end
          resource.legal.each do |f|
            f.contentAttachment = nil
            f.contentReference = FHIR::Reference.new
            f.contentReference.display = "DocumentReference #{SecureRandom.base64}" 
          end
          resource.rule.each do |f|
            f.contentAttachment = nil
            f.contentReference = FHIR::Reference.new
            f.contentReference.display = "DocumentReference #{SecureRandom.base64}" 
          end
        when FHIR::DataElement
          resource.mapping.each do |m|
            m.fhirIdentity = SecureRandom.base64 if m.fhirIdentity.nil?
            m.fhirIdentity.gsub!(/[^0-9A-Za-z]/, '')
          end
        when FHIR::DeviceMetric
          resource.measurementPeriod = nil
        when FHIR::DiagnosticReport
          date = DateTime.now
          resource.effectiveDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectivePeriod = nil
        when FHIR::DocumentManifest
          resource.content.each do |c|
            c.pAttachment = nil
            c.pReference = FHIR::Reference.new
            c.pReference.display = "Reference(Any) #{SecureRandom.base64}"
          end
        when FHIR::DocumentReference
          resource.docStatus = minimal_codeableconcept('http://hl7.org/fhir/composition-status','preliminary')
        when FHIR::ElementDefinition
          keys = []
          resource.constraint.each do |constraint|
            constraint.key = SecureRandom.base64 if constraint.key.nil?
            constraint.key.gsub!(/[^0-9A-Za-z]/, '')
            keys << constraint.key
            constraint.xpath = "/"
          end
          resource.condition = keys
          resource.mapping.each do |m|
            m.fhirIdentity = SecureRandom.base64 if m.fhirIdentity.nil?
            m.fhirIdentity.gsub!(/[^0-9A-Za-z]/, '')
          end
          resource.max = "#{resource.min+1}"
          # TODO remove bindings for things that can't be code, Coding, CodeableConcept
          is_codeable = false
          resource.fhirType.each do |f|
            is_codeable = (['code','Coding','CodeableConcept'].include?(f.code))
          end
          resource.binding = nil unless is_codeable
        when FHIR::Immunization
          if resource.wasNotGiven
            resource.explanation.reasonNotGiven = textonly_codeableconcept("reasonNotGiven #{SecureRandom.base64}")
            resource.explanation.reason = nil
            resource.reaction = nil
          else
            resource.explanation.reasonNotGiven = nil
            resource.explanation.reason = textonly_codeableconcept("reason #{SecureRandom.base64}")
          end
        when FHIR::Media
          if resource.fhirType == 'video'
            resource.frames = nil
          elsif resource.fhirType == 'photo'
            resource.duration = nil
          elsif resource.fhirType == 'audio'
            resource.height = nil
            resource.width = nil
            resource.frames = nil            
          else
            resource.height = nil
            resource.width = nil
            resource.frames = nil
          end
        when FHIR::Medication
          if resource.product.try(:ingredient)
            resource.product.ingredient.each {|i|i.amount = nil}
          end
        when FHIR::MedicationAdministration
          date = DateTime.now
          resource.effectiveTimeDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectiveTimePeriod = nil
          if resource.wasNotGiven
            resource.reasonGiven = nil
          else
            resource.reasonNotGiven = nil
          end
          resource.medicationReference = FHIR::Reference.new
          resource.medicationReference.display = "Medication #{SecureRandom.base64}" 
          resource.medicationCodeableConcept = nil
        when FHIR::MedicationDispense
          resource.medicationReference = FHIR::Reference.new
          resource.medicationReference.display = "Medication #{SecureRandom.base64}" 
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::MedicationOrder
          resource.medicationReference = FHIR::Reference.new
          resource.medicationReference.display = "Medication #{SecureRandom.base64}" 
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::MedicationStatement
          resource.reasonNotTaken = nil if resource.wasNotTaken != true
          resource.medicationReference = FHIR::Reference.new
          resource.medicationReference.display = "Medication #{SecureRandom.base64}" 
          resource.medicationCodeableConcept = nil
          resource.dosage.each{|d|d.timing=nil}
        when FHIR::MessageHeader
          resource.response.identifier.gsub!(/[^0-9A-Za-z]/, '') if resource.try(:response).try(:identifier)
        when FHIR::Order
          resource.when.schedule = nil
        when FHIR::Patient
          resource.maritalStatus = minimal_codeableconcept('http://hl7.org/fhir/v3/MaritalStatus','S')
        when FHIR::Procedure
          resource.reasonNotPerformed = nil if resource.notPerformed != true
          resource.focalDevice.each do |fd|
            fd.action = minimal_codeableconcept('http://hl7.org/fhir/ValueSet/device-action','implanted')
          end
        when FHIR::Questionnaire
          resource.group.required = true
          resource.group.group = nil
          resource.group.question.each {|q|q.options = nil }
        when FHIR::QuestionnaireResponse
          resource.group.group = nil
          resource.group.question.each {|q|q.answer = nil }
        else
          # default
        end
      end

    end
  end
end
