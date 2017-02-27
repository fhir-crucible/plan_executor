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
        set_fields!(resource, embedded)
        resource.id=nil if resource.respond_to?(:id=)
        resource.versionId=nil if resource.respond_to?(:versionId=)
        resource.version=nil if resource.respond_to?(:version=)
        resource.meta=FHIR::Meta.new({ 'tag' => [{'system'=>'http://projectcrucible.org', 'code'=>'testdata'}]}) if resource.respond_to?(:meta=)
        #resource.text=nil if [FHIR::Bundle,FHIR::Binary].include?(klass)
        apply_invariants!(resource)
        resource
      end

      #
      # Set the fields of this resource to have some random values.
      #
      def self.set_fields!(resource, embedded=0)

        unselected_multiples = []
        if resource.class.constants.include? :MULTIPLE_TYPES
          multiples = resource.class::MULTIPLE_TYPES.keys
          all_multiples = multiples.map{|k| resource.class::MULTIPLE_TYPES[k].map{|d| "#{k}#{d.titleize.split.join}" }}.flatten
          selected_multiples = multiples.map{|k| "#{k}#{resource.class::MULTIPLE_TYPES[k].sample.titleize.split.join}" }
          unselected_multiples = all_multiples - selected_multiples
        end
        unselected_multiples.each do |key|
          resource.method("#{key}=").call(nil)
        end

        resource.class::METADATA.each do |key, meta|
          type = meta['type']
          next if type == 'Meta'
		      next if ['id','contained','version','versionId','implicitRules'].include? key
          next if unselected_multiples.include?(key)

          gen = nil
          if type == 'string' || type == 'markdown'
            gen = SecureRandom.base64
          elsif type == 'oid'
            gen = random_oid
          elsif type == 'id'
            gen = SecureRandom.uuid
          elsif type == 'code'
            if meta['valid_codes']
              gen = meta['valid_codes'].values.first.sample
            elsif meta['binding'] && ['http://tools.ietf.org/html/bcp47','http://hl7.org/fhir/ValueSet/languages'].include?(meta['binding']['uri'])
              gen = 'en-US'
            elsif meta['binding'] && ['http://www.rfc-editor.org/bcp/bcp13.txt','http://hl7.org/fhir/ValueSet/content-type'].include?(meta['binding']['uri'])
              gen = MIME::Types.to_a.sample.content_type
            else
              gen = SecureRandom.base64
            end
          elsif type == 'xhtml'
            gen = "<div>#{SecureRandom.base64}</div>"
          elsif type == 'uri'
            gen = "http://projectcrucible.org/#{SecureRandom.base64}"
          elsif type == 'dateTime' || type == 'instant'
            gen = DateTime.now.strftime("%Y-%m-%dT%T.%LZ")
          elsif type == 'date'
            gen = DateTime.now.strftime("%Y-%m-%d")
          elsif type == 'time'
            gen = DateTime.now.strftime("%T")
          elsif type == 'boolean'
            gen = (SecureRandom.random_number(100) % 2 == 0)
          elsif type == 'positiveInt' || type == 'unsignedInt' || type == 'integer'
             gen = (SecureRandom.random_number(100) + 1) # add one in case this is a "positiveInt" which must be > 0
          elsif type == 'decimal'
            gen = SecureRandom.random_number
            while gen.to_s.match(/e/) # according to FHIR spec: decimals may not contain exponents
              gen = SecureRandom.random_number
            end
          elsif type == 'base64Binary'
            gen = SecureRandom.base64
          elsif FHIR::RESOURCES.include?(type)
            if embedded > 0
              gen = generate_child(type, embedded-1)
            end
          elsif FHIR::TYPES.include?(type)
            if embedded > 0
              gen = generate_child(type, embedded-1)
              # apply bindings
              if type == 'CodeableConcept' && meta['valid_codes'] && meta['binding']
                gen.coding.each do |c|
                  c.system = meta['valid_codes'].keys.sample
                  c.code = meta['valid_codes'][c.system].sample
                  display = FHIR::Definitions.get_display(c.system, c.code)
                  c.display = display ? display : nil
                end
              elsif type == 'CodeableConcept' && meta['binding'] && meta['binding']['uri'] == 'http://hl7.org/fhir/ValueSet/use-context'
                gen.coding.each do |c|
                  c.system = 'https://www.usps.com/'
                  c.code = ['CA','TX','NY','MA','DC'].sample
                end
              elsif type == 'Coding' && meta['valid_codes'] && meta['binding']
                gen.system = meta['valid_codes'].keys.sample
                gen.code = meta['valid_codes'][gen.system].sample
                display = FHIR::Definitions.get_display(gen.system, gen.code)
                gen.display = display ? display : nil
              elsif type == 'Reference'
                gen.reference = nil
                gen.display = "#{meta['type_profiles'].map{|x|x.split('/').last}.sample} #{gen.display}" if meta['type_profiles']
              elsif type == 'Attachment'
                gen.contentType = MIME::Types.to_a.sample.content_type
                gen.data = nil
              elsif type == 'Narrative'
                gen.status = 'generated'
              end
            end
          elsif resource.class.constants.include? type.demodulize.to_sym
            if embedded > 0
              # CHILD component
              gen = generate_child(type, embedded-1)
            end
          elsif ancestor_fhir_classes(resource.class).include? type.demodulize.to_sym
            if embedded > 0
              gen = generate_child(type, embedded-1)
            end
          elsif ("FHIR::#{type}".constantize rescue nil)
            if embedded > 0
              gen = generate_child(type, embedded-1)
            end
          else
            puts "Unable to generate field #{key} for #{resource.class} -- unrecognized type: #{type}"
          end
          method = meta['local_name'] ? meta['local_name'] : key
          gen = [gen] if meta['max'] > 1 && !gen.nil?
          resource.method("#{method}=").call(gen) if !gen.nil?
        end
        resource
      end

      def self.ancestor_fhir_classes(klass)
        classes = klass.constants
        classes.concat ancestor_fhir_classes(klass.parent) if klass.parent != FHIR && klass.parent != Object
        classes
      end

      def self.generate_child(type, embedded=0)
        return if ['Meta','Extension','PrimitiveExtension'].include? type
        klass = "FHIR::#{type}".constantize
        generate(klass, embedded)
      end

      def self.random_oid
        oid = "urn:oid:2"
        SecureRandom.random_number(12).times do |i|
          oid = "#{oid}.#{SecureRandom.random_number(500)}"
        end
        oid
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
        resource.subject = FHIR::Reference.new
        if patientId
          resource.subject.reference = "Patient/#{patientId}"
        else
          resource.subject.display = 'Patient'
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
        hn.family = 'Crucible'
        hn.given = [ name ]
        hn.text = "#{hn.given[0]} #{hn.family}"
        hn
      end

      def self.textonly_codeableconcept(text='text')
        concept = FHIR::CodeableConcept.new
        concept.text = text
        concept
      end

      def self.textonly_reference(text='Reference')
        ref = FHIR::Reference.new
        ref.display = "#{text} #{SecureRandom.base64}"
        ref
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
        animal = FHIR::Patient::Animal.new
        animal.species = minimal_codeableconcept('http://hl7.org/fhir/animal-species','canislf') # dog
        animal.breed = minimal_codeableconcept('http://hl7.org/fhir/animal-breed','gret') # golden retriever
        animal.genderStatus = minimal_codeableconcept('http://hl7.org/fhir/animal-genderstatus','intact') # intact
        animal
      end

      def self.apply_invariants!(resource)
        case resource
        when FHIR::Age 
          resource.system = 'http://unitsofmeasure.org'
          resource.code = 'a'
          resource.value = (SecureRandom.random_number(100) + 1)
          resource.unit = nil
          resource.comparator = nil
        when FHIR::AllergyIntolerance
          resource.clinicalStatus = nil if resource.verificationStatus=='entered-in-error'
        when FHIR::Duration 
          resource.system = 'http://unitsofmeasure.org'
          resource.code = 'mo'
          resource.unit = nil
          resource.comparator = nil
        when FHIR::Money 
          resource.system = 'urn:iso:std:iso:4217'
          resource.code = 'USD'
          resource.unit = nil
          resource.comparator = nil 
        when FHIR::Appointment
          resource.reason = minimal_codeableconcept('http://snomed.info/sct','219006') # drinker of alcohol
          resource.participant.each{|p| p.type=[ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency') ] }
        when FHIR::AppointmentResponse
          resource.participantType = [ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency') ]
        when FHIR::AuditEvent
          resource.entity.each do |o|
            o.query=nil
            o.name = "name #{SecureRandom.base64}" if o.name.nil?
          end
        when FHIR::Bundle
          resource.type = ['document','message','collection'].sample
          resource.total = nil if !['searchset','history'].include?(resource.type)
          resource.entry.each {|e|e.search=nil} if resource.type!='searchset'
          resource.entry.each {|e|e.request=nil} if !['batch','transaction','history'].include?(resource.type)
          resource.entry.each {|e|e.response=nil} if !['batch-response','transaction-response'].include?(resource.type)
          head = resource.entry.first
          if !head.nil?
            if resource.type == 'document'
              head.resource = generate(FHIR::Composition,3)
            elsif resource.type == 'message'
              head.resource = generate(FHIR::MessageHeader,3)  
            else
              head.resource = generate(FHIR::Basic,3)                              
            end
            rid = SecureRandom.random_number(100) + 1
            head.fullUrl = "http://projectcrucible.org/fhir/#{head.resource.resourceType}/#{rid}"
            head.resource.id = "#{rid}"
          end
        when FHIR::CarePlan
          resource.activity.each {|a| a.reference = nil if a.detail }
        when FHIR::CodeSystem
          resource.concept.each do |c|
            c.concept.each do |d|
              d.property.each do |p|
                p.valueCode = nil
                p.valueCoding = nil
                p.valueString = SecureRandom.base64
                p.valueInteger = nil
                p.valueBoolean = nil
                p.valueDateTime = nil
              end
            end
          end
        when FHIR::CapabilityStatement
          resource.kind = 'instance'
          resource.rest.each do |r|
            r.resource.each do |res|
              res.interaction.each{|i|i.code = ['read', 'vread', 'update', 'delete', 'history-instance', 'history-type', 'create', 'search-type'].sample}
            end
            r.interaction.each{|i|i.code = ['transaction', 'batch', 'search-system', 'history-system'].sample }
          end
        when FHIR::Claim
          resource.item.each do |item|
            item.category = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
            item.detail.each do |detail|
              detail.category = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
              detail.subDetail.each do |sub|
                sub.category = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV')
                sub.service = minimal_coding('http://hl7.org/fhir/ex-USCLS','1205')
              end
            end
          end
        when FHIR::ClaimResponse
          resource.item.each do |item|
            item.adjudication.each{|a|a.category = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
            item.detail.each do |detail|
              detail.adjudication.each{|a|a.category = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
              detail.subDetail.each do |sub|
                sub.adjudication.each{|a|a.category = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
              end
            end
          end
          resource.addItem.each do |addItem|
            addItem.adjudication.each{|a|a.category = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
            addItem.detail.each do |detail|
              detail.adjudication.each{|a|a.category = minimal_coding('http://hl7.org/fhir/adjudication','benefit')}
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
            resource.sourceReference = textonly_reference('ValueSet') 
          end
          if(resource.targetUri.nil? && resource.targetReference.nil?)
            resource.targetReference = textonly_reference('ValueSet') 
          end
        when FHIR::Condition
          if resource.onsetAge
            resource.onsetAge.system = 'http://unitsofmeasure.org'
            resource.onsetAge.code = 'a'
            resource.onsetAge.unit = 'yr'
            resource.onsetAge.comparator = nil
          end
          if resource.abatementAge
            resource.abatementAge.system = 'http://unitsofmeasure.org'
            resource.abatementAge.code = 'a'
            resource.abatementAge.unit = 'yr'
            resource.abatementAge.comparator = nil
          end
          # Make sure the onsetAge is before the abatementAge. If it's not (and both exist), flip them around
          if resource.onsetAge && resource.abatementAge
            if resource.onsetAge.value > resource.abatementAge.value
              # This is the "Ruby Way" to swap two variables without using a temporary third variable
              resource.onsetAge, resource.abatementAge = resource.abatementAge, resource.onsetAge
            end
          end
        when FHIR::CapabilityStatement
          resource.fhirVersion = 'STU3'
          resource.format = ['xml','json']
          if resource.kind == 'capability'
            resource.implementation = nil
          elsif resource.kind == 'requirements'
            resource.implementation = nil
            resource.software = nil
          end
          resource.messaging.each{|m| m.endpoint = nil} if resource.kind != 'instance'
        when FHIR::Contract
          resource.agent.each do |agent|
            agent.actor = textonly_reference('Patient')
          end
          resource.valuedItem.each do |item|
            if item.unitPrice
              item.unitPrice.system = 'urn:iso:std:iso:4217'
              item.unitPrice.code = 'USD'
              item.unitPrice.unit = nil
              item.unitPrice.comparator = nil
            end
            if item.net
              item.net.system = 'urn:iso:std:iso:4217'
              item.net.code = 'USD'
              item.net.unit = nil
              item.net.comparator = nil
            end
          end
          resource.term.each do |term|
            term.agent.each do |agent|
              agent.actor = textonly_reference('Organization')
            end
            term.group.each do |group|
              group.agent.each do |agent|
                agent.actor = textonly_reference('Organization')
              end
            end
            term.valuedItem.each do |item|
              if item.unitPrice
                item.unitPrice.system = 'urn:iso:std:iso:4217'
                item.unitPrice.code = 'USD'
                item.unitPrice.unit = nil
                item.unitPrice.comparator = nil
              end
              if item.net
                item.net.system = 'urn:iso:std:iso:4217'
                item.net.code = 'USD'
                item.net.unit = nil
                item.net.comparator = nil
              end
            end
          end
          resource.friendly.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference')
          end
          resource.legal.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference')
          end
          resource.rule.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference')
          end
        when FHIR::DataElement
          resource.mapping.each do |m|
            m.identity = SecureRandom.base64 if m.identity.nil?
            m.identity.gsub!(/[^0-9A-Za-z]/, '')
          end
        when FHIR::DeviceComponent
          resource.languageCode.coding.each do |c|
            c.system = 'http://tools.ietf.org/html/bcp47'
            c.code = 'en-US'
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
            c.pReference = textonly_reference('Any')
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
            m.identity = SecureRandom.base64 if m.identity.nil?
            m.identity.gsub!(/[^0-9A-Za-z]/, '')
          end
          resource.max = "#{resource.min+1}"
          # TODO remove bindings for things that can't be code, Coding, CodeableConcept
          is_codeable = false
          resource.type.each do |f|
            is_codeable = (['code','Coding','CodeableConcept'].include?(f.code))
            f.aggregation = []
          end
          resource.binding = nil unless is_codeable
          resource.contentReference = nil
          FHIR::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
            resource.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@fixed#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@pattern#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
          end
        when FHIR::ExpansionProfile
          resource.designation.exclude = nil
        when FHIR::FamilyMemberHistory
          if resource.ageAge
            resource.ageAge.system = 'http://unitsofmeasure.org'
            resource.ageAge.code = 'a'
            resource.ageAge.unit = nil
            resource.ageAge.comparator = nil
          end
          if SecureRandom.random_number(2)==0
            resource.bornPeriod = nil
            resource.bornDate = nil
            resource.bornString = nil
          else
            resource.ageAge = nil
            resource.ageRange = nil
            resource.ageString = nil
          end
          if resource.deceasedAge
            resource.deceasedAge.system = 'http://unitsofmeasure.org'
            resource.deceasedAge.code = 'a'
            resource.deceasedAge.unit = nil
            resource.deceasedAge.comparator = nil
          end
        when FHIR::Goal
          resource.outcome.each do |outcome|
            outcome.resultCodeableConcept = nil
            outcome.resultReference = textonly_reference('Observation')
          end
          if resource.targetDuration
            resource.targetDuration.system = 'http://unitsofmeasure.org'
            resource.targetDuration.code = 'a'
            resource.targetDuration.unit = nil
            resource.targetDuration.comparator = nil
          end
        when FHIR::Group
          resource.member = [] if resource.actual==false
          resource.characteristic.each do |c|
            c.valueCodeableConcept = nil
            c.valueBoolean = true
            c.valueQuantity = nil
            c.valueRange = nil
          end
        when FHIR::ImagingStudy
          resource.uid = random_oid
          availability = ['ONLINE', 'OFFLINE', 'NEARLINE', 'UNAVAILABLE']
          resource.series.each do |series|
            series.uid=random_oid
            series.availability = availability.sample
            series.instance.each do |instance|
              instance.uid = random_oid
              instance.sopClass = random_oid
            end
          end
          resource.availability = availability.sample
        when FHIR::ImagingManifest
          resource.title.coding.each{|c|c.code=['113000', '113002', '113003', '113004', '113005', '113006', '113007', '113008', '113009'].sample}
          resource.study.each do |study|
            study.series.each do |series|
              series.baseLocation.each do |b| 
                b.type = minimal_coding('http://hl7.org/fhir/dWebType',['WADO-RS', 'WADO-URI', 'IID'].sample)
                b.url = "http://projectcrucible.org/#{SecureRandom.base64}"
              end
              series.instance.each do |i|
                i.sopClass = random_oid
                i.uid = random_oid
              end
            end
          end
        when FHIR::Immunization
          if resource.wasNotGiven
            resource.explanation.reasonNotGiven = [ textonly_codeableconcept("reasonNotGiven #{SecureRandom.base64}") ]
            resource.explanation.reason = nil
            resource.reaction = nil
          else
            resource.explanation.reasonNotGiven = nil
            resource.explanation.reason = [ textonly_codeableconcept("reason #{SecureRandom.base64}") ]
          end
        when FHIR::ImplementationGuide
          resource.fhirVersion = "STU3"
          resource.package.each do |package|
            package.resource.each do |r|
              r.sourceUri = nil
              r.sourceReference = textonly_reference('Any')
            end
          end
        when FHIR::List
          resource.emptyReason = nil
          resource.entry.each do |entry|
            resource.mode = 'changes' if !entry.deleted.nil?
          end
        when FHIR::Media
          if resource.type == 'video'
            resource.frames = nil
          elsif resource.type == 'photo'
            resource.duration = nil
          elsif resource.type == 'audio'
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
          resource.effectiveDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectivePeriod = nil
          if resource.notGiven
            resource.reasonGiven = nil
          else
            resource.reasonNotGiven = nil
          end
          resource.medicationReference = textonly_reference('Medication')
          resource.medicationCodeableConcept = nil
        when FHIR::MedicationDispense
          resource.medicationReference = textonly_reference('Medication')
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::MedicationRequest
          resource.medicationReference = textonly_reference('Medication')
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::MedicationStatement
          resource.reasonNotTaken = nil if resource.notTaken != true
          resource.medicationReference = textonly_reference('Medication')
          resource.medicationCodeableConcept = nil
          resource.dosage.each{|d|d.timing=nil}
        when FHIR::MessageHeader
          resource.response.identifier.gsub!(/[^0-9A-Za-z]/, '') if resource.try(:response).try(:identifier)
        when FHIR::NamingSystem
          resource.replacedBy = nil if resource.status!='retired'
          if resource.kind == 'root'
            resource.uniqueId.each do |uid|
              uid.type='uuid'
              uid.value = SecureRandom.uuid
            end
          end
          resource.uniqueId.each do |uid|
            uid.preferred = nil
          end
        when FHIR::NutritionRequest
          resource.oralDiet.schedule = nil if resource.oralDiet
          resource.supplement.each{|s|s.schedule=nil}
          resource.enteralFormula.administration = nil if resource.enteralFormula
        when FHIR::OperationDefinition
          resource.parameter.each do |p|
            p.binding = nil
            p.part = nil
            p.searchType = nil unless p.type == 'string'
          end
        when FHIR::Patient
          resource.maritalStatus = minimal_codeableconcept('http://hl7.org/fhir/v3/MaritalStatus','S')
        when FHIR::PlanDefinition
          resource.actionDefinition.each do |a|
            a.actionDefinition.each do |b|
              b.relatedAction = []
            end
          end
        when FHIR::Procedure
          resource.reasonNotPerformed = nil if resource.notPerformed != true
          resource.focalDevice.each do |fd|
            code = ['implanted', 'explanted', 'manipulated'].sample
            fd.action = minimal_codeableconcept('http://hl7.org/fhir/device-action', code)
          end
        when FHIR::Provenance
          resource.entity.each do |e|
            e.agent.each{|a| a.relatedAgentType = nil }
          end
        when FHIR::Practitioner
          resource.communication.each do |comm|
            comm.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::RelatedPerson
          resource.relationship = minimal_codeableconcept('http://hl7.org/fhir/patient-contact-relationship','family')
        when FHIR::Questionnaire
          resource.item.each do |i|
            i.required = true
            i.item = []
            i.options = nil
            i.option = []
            if ['choice','open-choice'].include?(i.type)
              choice_a = FHIR::Questionnaire::Item::Option.new({'valueString'=>'true'})
              choice_b = FHIR::Questionnaire::Item::Option.new({'valueString'=>'false'})
              i.option = [ choice_a, choice_b ] 
            end
            if i.type=='display'
              i.required = nil
              i.repeats = nil
              i.readOnly = nil
              i.concept = []
              FHIR::Questionnaire::Item::MULTIPLE_TYPES['initial'].each do |type|
                i.instance_variable_set("@initial#{type.capitalize}".to_sym, nil)
              end
            end
            i.enableWhen.each do |ew|
              ew.hasAnswer = false
              ew.hasAnswer = nil if ew.answer
            end
            i.maxLength = nil if !['boolean', 'decimal', 'integer', 'string', 'text', 'url'].include?(i.type)
          end
        when FHIR::QuestionnaireResponse
          resource.item.each do |i|
            i.item = nil
            i.answer.each {|q|q.valueBoolean = true if !q.value }
          end
        when FHIR::Range
          # validate that the low/high values in the range are correct (e.g. the low value is not higher than the high value)
          if resource.low && resource.high
            if resource.low.value > resource.high.value
              # This is the "Ruby Way" to swap two variables without using a temporary third variable
              resource.low.value,resource.high.value = resource.high.value,resource.low.value
            end
          end
        when FHIR::Signature
          resource.type = [ minimal_coding('urn:iso-astm:E1762-95:2013','1.2.840.10065.1.12.1.18') ]
          resource.whoUri = 'http://projectcrucible.org'
          resource.whoReference = nil
        when FHIR::Subscription
          resource.status = 'requested' if resource.id.nil?
          resource.channel.payload = 'applicaton/json+fhir'
          resource.end = nil
          resource.criteria = 'Observation?code=http://loinc.org|1975-2'
        when FHIR::SupplyDelivery
          resource.type = minimal_codeableconcept('http://hl7.org/fhir/supply-item-type','medication')
        when FHIR::SupplyRequest
          resource.kind = minimal_codeableconcept('http://hl7.org/fhir/supply-kind','central')
          if resource.when 
            resource.when.schedule = nil
            resource.when.code = minimal_codeableconcept('http://snomed.info/sct','20050000') #biweekly
          end
        when FHIR::StructureDefinition
          resource.derivation = 'constraint'
          resource.fhirVersion = 'STU3'
          resource.baseDefinition = "http://hl7.org/fhir/StructureDefinition/#{resource.type}"
          is_pattern = (SecureRandom.random_number(2)==0)
          if resource.snapshot && resource.snapshot.element
            resource.snapshot.element.first.id = resource.type
            resource.snapshot.element.first.path = resource.type 
            resource.snapshot.element.first.label = nil
            resource.snapshot.element.first.code = nil
            resource.snapshot.element.first.requirements = nil
            resource.snapshot.element.first.type = nil
            if is_pattern
              FHIR::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
                resource.snapshot.element.first.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@fixed#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
              end
            else
              FHIR::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
                resource.snapshot.element.first.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@pattern#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
              end
            end
          end
          if resource.differential && resource.differential.element
            resource.differential.element[0] = resource.snapshot.element[0]
          end
          resource.mapping.each do |m|
            m.identity.gsub!(/[^0-9A-Za-z]/, '') if m.identity
          end
        when FHIR::StructureMap
          resource.group.each do |g|
            g.rule.each{|r|r.rule = nil}
          end
        when FHIR::TestScript
          resource.variable.each do |v|
            v.sourceId.gsub!(/[^0-9A-Za-z]/, '') if v.sourceId
            v.path = nil if v.headerField
          end
          if resource.setup
            resource.setup.action.each do |a|
              a.assert = nil if a.operation
              apply_invariants!(a.operation) if a.operation
              apply_invariants!(a.assert) if a.assert
            end
          end
          resource.test.each do |test|
            test.action.each do |a|
              a.assert = nil if a.operation
              apply_invariants!(a.operation) if a.operation
              apply_invariants!(a.assert) if a.assert
            end            
          end
          if resource.teardown
            resource.teardown.action.each do |a|
              apply_invariants!(a.operation) if a.operation
            end
          end
        when FHIR::TestScript::Setup::Action::Assert
          # an assertion can only contain one of these...
          keys = ['contentType','headerField','minimumId','navigationLinks','path','resource','responseCode','response','validateProfileId']
          has_keys = []
          keys.each do |key|
            has_keys << key if resource.try(key.to_sym)
          end
          # remove all assertions except the first
          has_keys[1..-1].each do |key|
            resource.send("#{key}=",nil)
          end
          resource.sourceId.gsub!(/[^0-9A-Za-z]/, '') if resource.sourceId
          resource.validateProfileId.gsub!(/[^0-9A-Za-z]/, '') if resource.validateProfileId
        when FHIR::TestScript::Setup::Action::Operation
          resource.responseId.gsub!(/[^0-9A-Za-z]/, '') if resource.responseId
          resource.sourceId.gsub!(/[^0-9A-Za-z]/, '') if resource.sourceId
          resource.targetId.gsub!(/[^0-9A-Za-z]/, '') if resource.targetId
        when FHIR::ValueSet
          if resource.compose
            resource.compose.include.each do |inc|
              inc.filter = nil if inc.concept
            end
            resource.compose.exclude.each do |exc|
              exc.filter = nil if exc.concept
            end
          end
        when FHIR::RequestGroup::Action
          if !resource.resource.nil? && resource.action.count > 0
            if SecureRandom.random_number(2)==0
              resource.resource = nil
            else
              resource.action = []
            end
          end
        else
          # default
        end
      end

    end
  end
end
