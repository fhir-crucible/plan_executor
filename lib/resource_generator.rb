module Crucible
  module Tests
    class ResourceGenerator

      # Allow to embed this many extra levels if min != 0.
      # We no longer cut off generation if an element has a min requirement.
      # This just guards an infinite loop case, if it is possible in FHIR
      EMBEDDED_LOOP_GUARD = 10
      #
      # Generate a FHIR resource for the given class `klass`
      # If `embedded` is greater than zero, alledded children will also
      # be generated.
      #
      def self.generate(klass,embedded=0)
        resource = klass.new
        namespace = 'FHIR'
        namespace = 'FHIR::DSTU2' if klass.name.starts_with? 'FHIR::DSTU2'
        namespace = 'FHIR::STU3' if klass.name.starts_with? 'FHIR::STU3'
        Time.zone = 'UTC'
        set_fields!(resource, namespace, embedded)
        resource.id=nil if resource.respond_to?(:id=)
        resource.versionId=nil if resource.respond_to?(:versionId=)
        resource.version=nil if resource.respond_to?(:version=)
        resource.meta="#{namespace}::Meta".constantize.new({ 'tag' => [{'system'=>'http://projectcrucible.org', 'code'=>'testdata'}]}) if resource.respond_to?(:meta=)
        apply_invariants!(resource)
        resource
      end

      #
      # Set the fields of this resource to have some random values.
      #
      def self.set_fields!(resource, namespace, embedded=0)

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
          elsif "#{namespace}::RESOURCES".constantize.include?(type)
            if embedded > 0 || ((meta['binding'] || meta['min'] != 0) && EMBEDDED_LOOP_GUARD + embedded > 0)
              gen = generate_child(type, namespace, embedded-1)
            end
          elsif "#{namespace}::TYPES".constantize.include?(type)
            if embedded > 0 || ((type == 'Coding' || meta['binding'] || meta['min'] != 0) && EMBEDDED_LOOP_GUARD + embedded > 0)
              gen = generate_child(type, namespace, embedded-1)
              # apply bindings
              if type == 'CodeableConcept' && meta['valid_codes'] && meta['binding']
                gen.coding.each do |c|
                  c.system = meta['valid_codes'].keys.sample
                  c.code = meta['valid_codes'][c.system].sample
                  display = "#{namespace}::Definitions".constantize.get_display(c.system, c.code) if "#{namespace}::Definitions".constantize.respond_to?('get_display')
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
                display = "#{namespace}::Definitions".constantize.get_display(gen.system, gen.code) if "#{namespace}::Definitions".constantize.respond_to?('get_display')
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
            if embedded > 0 || ((meta['binding'] || meta['min'] != 0) && EMBEDDED_LOOP_GUARD + embedded > 0)
              # CHILD component
              gen = generate_child(type, namespace, embedded-1)
            end
          elsif ancestor_fhir_classes(resource.class, namespace).include? type.demodulize.to_sym
            if embedded > 0 || ((meta['binding'] || meta['min'] != 0) && EMBEDDED_LOOP_GUARD + embedded > 0)
              gen = generate_child(type, namespace, embedded-1)
            end
          elsif ("#{namespace}::#{type}".constantize rescue nil)
            if embedded > 0 || ((meta['binding'] || meta['min'] != 0) && EMBEDDED_LOOP_GUARD + embedded > 0)
              gen = generate_child(type, namespace, embedded-1)
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

      def self.ancestor_fhir_classes(klass,namespace)
        classes = klass.constants
        classes.concat ancestor_fhir_classes(klass.parent, namespace) if klass.parent.name != namespace && klass.parent != Object
        classes
      end

      def self.generate_child(type, namespace, embedded=0)
        return if ['Meta','Extension','PrimitiveExtension'].include? type
        klass = "#{namespace}::#{type}".constantize
        generate(klass, embedded)
      end

      def self.random_oid
        #	Regex: urn:oid:[0-2](\.[1-9]\d*)+ (http://hl7.org/fhir/STU3/datatypes.html#oid)
        oid = "urn:oid:2"
        rand(1..12).times do
          oid = "#{oid}.#{rand(1..500)}"
        end
        oid
      end

      def self.minimal_patient(identifier='0',name='Name', namespace = FHIR)
        resource = namespace.const_get(:Patient).new
        resource.identifier = [ minimal_identifier(identifier) ]
        resource.name = [ minimal_humanname(name) ]
        tag_metadata(resource)
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      # units: must be UCOM
      def self.minimal_observation(system='http://loinc.org',code='8302-2',value=170,units='cm',patientId=nil, namespace = FHIR)
        resource = namespace.const_get(:Observation).new
        resource.status = 'final'
        resource.code = minimal_codeableconcept(system,code, namespace)
        if patientId
          ref = namespace.const_get(:Reference).new
          ref.reference = "Patient/#{patientId}"
          resource.subject = ref
        end
        resource.valueQuantity = minimal_quantity(value,units, namespace)
        tag_metadata(resource)
      end

      # Default system/code are for SNOMED "Obese (finding)"
      def self.minimal_condition(system='http://snomed.info/sct',code='414915002',patientId=nil, namespace = FHIR)
        resource = namespace.const_get(:Condition).new
        resource.subject = namespace.const_get(:Reference).new
        if patientId
          resource.subject.reference = "Patient/#{patientId}"
        else
          resource.subject.display = 'Patient'
        end
        resource.code = minimal_codeableconcept(system,code, namespace)
        resource.verificationStatus = 'confirmed'
        tag_metadata(resource)
      end

      def self.minimal_identifier(identifier='0', namespace = FHIR)
        mid = namespace.const_get(:Identifier).new
        mid.use = 'official'
        mid.system = 'http://projectcrucible.org'
        mid.value = identifier
        mid
      end

      def self.minimal_humanname(name='Name', namespace = FHIR)
        hn = namespace.const_get(:HumanName).new
        hn.use = 'official'
        hn.family = 'Crucible'
        hn.given = [ name ]
        hn.text = "#{hn.given[0]} #{hn.family}"
        hn
      end

      def self.textonly_codeableconcept(text='text', namespace = FHIR)
        concept = namespace.const_get(:CodeableConcept).new
        concept.text = text
        concept
      end

      def self.textonly_reference(text='Reference', namespace = FHIR)
        ref = namespace.const_get(:Reference).new
        ref.display = "#{text} #{SecureRandom.base64}"
        ref
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      def self.minimal_codeableconcept(system='http://loinc.org',code='8302-2', namespace = FHIR)
        concept = namespace.const_get(:CodeableConcept).new
        concept.coding = [ minimal_coding(system,code,namespace) ]
        concept
      end

      # Common systems:
      #   SNOMED  http://snomed.info/sct
      #   LOINC   http://loinc.org
      #   ICD-10  http://hl7.org/fhir/sid/icd-10
      def self.minimal_coding(system='http://loinc.org',code='8302-2',namespace = FHIR)
        coding = namespace.const_get(:Coding).new
        coding.system = system
        coding.code = code
        coding
      end

      def self.minimal_quantity(value=170,units='cm', namespace = FHIR)
        quantity = namespace.const_get(:Quantity).new
        quantity.value = value
        quantity.unit = units
        quantity.system = 'http://unitsofmeasure.org'
        quantity
      end

      def self.minimal_animal(namespace = FHIR)
        animal = namespace.const_get(:Patient).const_get(:Animal).new
        animal.species = minimal_codeableconcept('http://hl7.org/fhir/animal-species','canislf', namespaec) # dog
        animal.breed = minimal_codeableconcept('http://hl7.org/fhir/animal-breed','gret', namespaec) # golden retriever
        animal.genderStatus = minimal_codeableconcept('http://hl7.org/fhir/animal-genderstatus','intact', namespaec) # intact
        animal
      end

      def self.tag_metadata(resource, namespace = FHIR)
        return nil unless resource

        if resource.meta.nil?
          resource.meta = namespace.const_get(:Meta).new({ 'tag' => [{'system'=>'http://projectcrucible.org', 'code'=>'testdata'}]})
        else
          resource.meta.tag << @namespace.const_get(:Coding).new({'system'=>'http://projectcrucible.org', 'code'=>'testdata'})
        end
        resource
      end

      def self.apply_invariants!(resource)
        case resource
        ## STU3
        when FHIR::STU3::ActivityDefinition
          resource.quantity.comparator = nil unless resource.quantity.nil?
        when FHIR::STU3::Age 
          resource.system = 'http://unitsofmeasure.org'
          resource.code = 'a'
          resource.value = (SecureRandom.random_number(100) + 1)
          resource.unit = nil
          resource.comparator = nil
        when FHIR::STU3::AllergyIntolerance
          resource.clinicalStatus = nil if resource.verificationStatus=='entered-in-error'
        when FHIR::STU3::Duration 
          resource.system = 'http://unitsofmeasure.org'
          resource.code = 'mo'
          resource.unit = nil
          resource.comparator = nil
        when FHIR::STU3::Money 
          resource.system = 'urn:iso:std:iso:4217'
          resource.code = 'USD'
          resource.unit = nil
          resource.comparator = nil 
        when FHIR::STU3::Appointment
          resource.reason = [ minimal_codeableconcept('http://snomed.info/sct','219006', FHIR::STU3) ] # drinker of alcohol
          resource.participant.each{|p| p.type=[ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency', FHIR::STU3) ] }
        when FHIR::STU3::AppointmentResponse
          resource.participantType = [ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency', FHIR::STU3) ]
        when FHIR::STU3::AuditEvent
          resource.entity.each do |o|
            o.query=nil
            o.name = "name #{SecureRandom.base64}" if o.name.nil?
          end
        when FHIR::STU3::Bundle
          resource.type = ['document','message','collection'].sample
          resource.total = nil if !['searchset','history'].include?(resource.type)
          resource.entry.each {|e|e.search=nil} if resource.type!='searchset'
          resource.entry.each {|e|e.request=nil} if !['batch','transaction','history'].include?(resource.type)
          resource.entry.each {|e|e.response=nil} if !['batch-response','transaction-response'].include?(resource.type)
          head = resource.entry.first
          if !head.nil?
            if resource.type == 'document'
              head.resource = generate(FHIR::STU3::Composition,3)
            elsif resource.type == 'message'
              head.resource = generate(FHIR::STU3::MessageHeader,3)  
            else
              head.resource = generate(FHIR::STU3::Basic,3)                              
            end
            rid = SecureRandom.random_number(100) + 1
            head.fullUrl = "http://projectcrucible.org/fhir/#{head.resource.resourceType}/#{rid}"
            head.resource.id = "#{rid}"
          end
        when FHIR::STU3::CarePlan
          resource.activity.each do |a|
            unless a.detail.nil?
              a.reference = nil
              a.detail.dailyAmount.comparator = nil unless a.detail.dailyAmount.nil?
              a.detail.quantity.comparator = nil unless a.detail.quantity.nil?
            end
          end
        when FHIR::STU3::CareTeam
          resource.participant.each do |p|
            p.onBehalfOf = nil
          end
        when FHIR::STU3::CodeSystem
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
        when FHIR::STU3::CapabilityStatement
          resource.kind = 'instance'
          resource.rest.each do |r|
            r.resource.each do |res|
              res.interaction.each{|i|i.code = ['read', 'vread', 'update', 'delete', 'history-instance', 'history-type', 'create', 'search-type'].sample}
            end
            r.interaction.each{|i|i.code = ['transaction', 'batch', 'search-system', 'history-system'].sample }
          end
          resource.messaging.each do |m|
            m.supportedMessage = [] if m.event.length > 0
          end
        when FHIR::STU3::Claim
          resource.item.each do |item|
            item.category = minimal_codeableconcept('http://hl7.org/fhir/benefit-subcategory','35', FHIR::STU3)
            item.quantity.comparator = nil unless item.quantity.nil?
            item.detail.each do |detail|
              detail.category = item.category
              detail.quantity.comparator = nil unless detail.quantity.nil?
              detail.subDetail.each do |sub|
                sub.category = item.category
                sub.quantity.comparator = nil unless sub.quantity.nil?
                sub.service = minimal_codeableconcept('http://hl7.org/fhir/ex-USCLS','1205', FHIR::STU3)
              end
            end
          end
        when FHIR::STU3::ClaimResponse
          resource.item.each do |item|
            item.adjudication.each{|a|a.category = minimal_codeableconcept('http://hl7.org/fhir/adjudication','benefit', FHIR::STU3)}
            item.detail.each do |detail|
              detail.adjudication.each{|a|a.category = minimal_codeableconcept('http://hl7.org/fhir/adjudication','benefit', FHIR::STU3)}
              detail.subDetail.each do |sub|
                sub.adjudication.each{|a|a.category = minimal_codeableconcept('http://hl7.org/fhir/adjudication','benefit', FHIR::STU3)}
              end
            end
          end
          resource.addItem.each do |addItem|
            addItem.adjudication.each{|a|a.category = minimal_codeableconcept('http://hl7.org/fhir/adjudication','benefit', FHIR::STU3)}
            addItem.detail.each do |detail|
              detail.adjudication.each{|a|a.category = minimal_codeableconcept('http://hl7.org/fhir/adjudication','benefit', FHIR::STU3)}
            end
          end
        when FHIR::STU3::Communication
          resource.payload = nil
        when FHIR::STU3::CommunicationRequest
          resource.payload = nil
          resource.requester.onBehalfOf = nil unless resource.requester.nil?
        when FHIR::STU3::Composition
          resource.attester.each {|a| a.mode = ['professional']}
          resource.section.each do |section|
            section.emptyReason = nil
            section.section.each do |sub|
              sub.emptyReason = nil
              sub.section = nil
            end
          end
        when FHIR::STU3::ConceptMap
          if(resource.sourceUri.nil? && resource.sourceReference.nil?)
            resource.sourceReference = textonly_reference('ValueSet', FHIR::STU3) 
          end
          if(resource.targetUri.nil? && resource.targetReference.nil?)
            resource.targetReference = textonly_reference('ValueSet', FHIR::STU3) 
          end
        when FHIR::STU3::Condition
          if resource.onsetAge
            resource.onsetAge.system = 'http://unitsofmeasure.org'
            resource.onsetAge.code = 'a'
            resource.onsetAge.unit = 'yr'
            resource.onsetAge.comparator = nil
          end
          resource.clinicalStatus = ['inactive', 'resolved','remission'].sample unless resource.abatement.nil?
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
        when FHIR::STU3::CapabilityStatement
          resource.fhirVersion = 'STU3'
          resource.format = ['xml','json']
          if resource.kind == 'capability'
            resource.implementation = nil
          elsif resource.kind == 'requirements'
            resource.implementation = nil
            resource.software = nil
          end
          resource.messaging.each{|m| m.endpoint = nil} if resource.kind != 'instance'
        when FHIR::STU3::Contract
          resource.agent.each do |agent|
            agent.actor = textonly_reference('Patient', FHIR::STU3)
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
            item.quantity.comparator = nil unless item.quantity.nil?
          end
          resource.term.each do |term|
            term.agent.each do |agent|
              agent.actor = textonly_reference('Organization', FHIR::STU3)
            end
            term.group.each do |group|
              group.agent.each do |agent|
                agent.actor = textonly_reference('Organization', FHIR::STU3)
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
              item.quantity.comparator = nil unless item.quantity.nil?
            end
          end
          resource.friendly.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::STU3)
          end
          resource.legal.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::STU3)
          end
          resource.rule.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::STU3)
          end
        when FHIR::STU3::DataElement
          resource.mapping.each do |m|
            m.identity = SecureRandom.base64 if m.identity.nil?
            m.identity.gsub!(/[^0-9A-Za-z]/, '')
          end
          resource.jurisdiction = []
        when FHIR::STU3::DeviceComponent
          unless resource.languageCode.nil?
            resource.languageCode.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::STU3::DeviceMetric
          resource.measurementPeriod = nil
        when FHIR::STU3::DiagnosticReport
          date = DateTime.now
          resource.effectiveDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectivePeriod = nil
        when FHIR::STU3::DocumentManifest
          resource.content.each do |c|
            c.pAttachment = nil
            c.pReference = textonly_reference('Any', FHIR::STU3)
          end
        when FHIR::STU3::DocumentReference
          resource.docStatus = 'preliminary'
        when FHIR::STU3::Dosage
          if !resource.doseRange.nil?
            resource.doseRange.low.comparator = nil unless resource.doseRange.low.nil?
            resource.doseRange.high.comparator = nil unless resource.doseRange.high.nil?
          end
          resource.doseQuantity.comparator = nil unless resource.doseQuantity.nil?
          resource.maxDosePerAdministration.comparator = nil unless resource.maxDosePerAdministration.nil?
          resource.maxDosePerLifetime.comparator = nil unless resource.maxDosePerLifetime.nil?
          if !resource.rateRange.nil?
            resource.rateRange.low.comparator = nil unless resource.rateRange.low.nil?
            resource.rateRange.high.comparator = nil unless resource.rateRange.high.nil?
          end
          resource.rateQuantity.comparator = nil unless resource.rateQuantity.nil?
        when FHIR::STU3::ElementDefinition
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
          FHIR::STU3::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
            resource.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@fixed#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@pattern#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
            resource.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
          end
        when FHIR::STU3::EligibilityResponse
          resource.insurance.each do |i|
            i.benefitBalance.each do |b|
              b.financial = []
            end
          end
        when FHIR::STU3::ExpansionProfile
          resource.designation.exclude = nil unless resource.designation.nil?
          resource.fixedVersion.each {|v| v.version = 'v1'}
        when FHIR::STU3::ExplanationOfBenefit
          resource.item.each do |item|
            item.detail = []
            item.quantity.comparator = nil unless item.quantity.nil?
          end
          resource.addItem.each do |item|
            item.detail = []
          end
        when FHIR::STU3::FamilyMemberHistory
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
          if resource.age.nil?
            resource.estimatedAge = nil
          end
          if resource.deceasedAge
            resource.deceasedAge.system = 'http://unitsofmeasure.org'
            resource.deceasedAge.code = 'a'
            resource.deceasedAge.unit = nil
            resource.deceasedAge.comparator = nil
          end
        when FHIR::STU3::Goal
          resource.outcomeCode.each do |code|
            code = nil
          end
          resource.outcomeReference.each do |reference|
            reference = textonly_reference('Observation', FHIR::STU3)
          end
          if resource.target && resource.target.dueDuration
            resource.target.dueDuration.system = 'http://unitsofmeasure.org'
            resource.target.dueDuration.code = 'a'
            resource.target.dueDuration.unit = nil
            resource.target.dueDuration.comparator = nil
          end
        when FHIR::STU3::Group
          resource.member = [] if resource.actual==false
          resource.characteristic.each do |c|
            c.valueCodeableConcept = nil
            c.valueBoolean = true
            c.valueQuantity = nil
            c.valueRange = nil
          end
        when FHIR::STU3::ImagingStudy
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
        when FHIR::STU3::ImagingManifest
          resource.study.each do |study|
            study.series.each do |series|
              series.instance.each do |i|
                i.sopClass = random_oid
                i.uid = random_oid
              end
            end
          end
        when FHIR::STU3::Immunization
          resource.doseQuantity.comparator = nil unless resource.doseQuantity.nil?
          if resource.notGiven
            unless resource.explanation.nil?
              resource.explanation.reasonNotGiven = [ textonly_codeableconcept("reasonNotGiven #{SecureRandom.base64}", FHIR::STU3) ]
              resource.explanation.reason = nil
            end
            resource.reaction = nil
          else
            unless resource.explanation.nil?
              resource.explanation.reasonNotGiven = nil
              resource.explanation.reason = [ textonly_codeableconcept("reason #{SecureRandom.base64}", FHIR::STU3) ]
            end
          end
          resource.status = ['completed','entered-in-error'].sample
        when FHIR::STU3::ImplementationGuide
          resource.fhirVersion = "STU3"
          resource.package.each do |package|
            package.resource.each do |r|
              r.sourceUri = nil
              r.sourceReference = textonly_reference('Any', FHIR::STU3)
            end
          end
        when FHIR::STU3::Linkage
          if resource.item.length == 1
            resource.item << resource.item.first # must have 2
          end
        when FHIR::STU3::List
          resource.emptyReason = nil
          resource.entry.each do |entry|
            resource.mode = 'changes' if !entry.deleted.nil?
          end
        when FHIR::STU3::Media
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
        when FHIR::STU3::Medication
          resource.ingredient.each do |i|
            i.amount = nil
          end
          unless resource.package.nil?
            resource.package.content.each do |c|
              c.amount = nil
            end
          end
        when FHIR::STU3::MedicationAdministration
          date = DateTime.now
          resource.effectiveDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectivePeriod = nil
          if resource.notGiven
            resource.reasonCode = nil
          else
            resource.reasonNotGiven = nil
          end
          resource.medicationReference = textonly_reference('Medication', FHIR::STU3)
          resource.medicationCodeableConcept = nil
          unless resource.dosage.nil?
            resource.dosage.dose.comparator = nil unless resource.dosage.dose.nil?
            resource.dosage.rateQuantity = nil
          end
        when FHIR::STU3::MedicationDispense
          resource.medicationReference = textonly_reference('Medication', FHIR::STU3)
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
          resource.quantity.comparator = nil unless resource.quantity.nil?
          resource.daysSupply.comparator = nil unless resource.daysSupply.nil?
        when FHIR::STU3::MedicationRequest
          resource.medicationReference = textonly_reference('Medication', FHIR::STU3)
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
          resource.dispenseRequest.quantity.comparator = nil if resource&.dispenseRequest&.quantity != nil
        when FHIR::STU3::MedicationStatement
          resource.reasonNotTaken = nil unless resource.taken == 'n'
          resource.medicationReference = textonly_reference('Medication', FHIR::STU3)
          resource.medicationCodeableConcept = nil
          resource.dosage.each{|d|d.timing=nil}
        when FHIR::STU3::MessageDefinition
          resource.focus.each do |f|
            f.max = '*' unless f.max.nil?
          end
        when FHIR::STU3::MessageHeader
          resource.response.identifier.gsub!(/[^0-9A-Za-z]/, '') if resource.try(:response).try(:identifier)
        when FHIR::STU3::NamingSystem
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
        when FHIR::STU3::NutritionOrder
          if resource.oralDiet
            resource.oralDiet.schedule = nil 
            resource.oralDiet.nutrient.each { |n| n.amount.comparator = nil unless n.amount.nil? }
          end
          resource.supplement.each{|s|s.schedule=nil}
          resource.supplement.each{|s|s.quantity=nil}
          unless resource.enteralFormula.nil?
            resource.enteralFormula.administration = nil 
            resource.enteralFormula.caloricDensity.comparator = nil unless resource.enteralFormula.caloricDensity.nil?
            resource.enteralFormula.maxVolumeToDeliver.comparator = nil unless resource.enteralFormula.maxVolumeToDeliver.nil?
            resource.enteralFormula.administration.each do |a|
              a.rateQuantity = nil
            end unless resource.enteralFormula.administration.nil?
          end
          resource.supplement.each { |s| s.quantity.comparator = nil unless s.quantity.nil? }
        when FHIR::STU3::Observation
          resource.referenceRange.each do |range|
            range.low.comparator = nil unless range.low.nil?
            range.high.comparator = nil unless range.high.nil?
          end
          resource.component.each do |component|
            if !component.valueRange.nil?
              component.valueRange.low.comparator = nil unless component.valueRange.low.nil?
              component.valueRange.high.comparator = nil unless component.valueRange.high.nil?
            end
            component.referenceRange.each do |range|
              range.low.comparator = nil unless range.low.nil?
              range.high.comparator = nil unless range.high.nil?
            end
          end

        when FHIR::STU3::OperationDefinition
          resource.parameter.each do |p|
            p.binding = nil
            p.part = nil
            p.searchType = nil unless p.type == 'string'
          end
        when FHIR::STU3::Patient
          resource.maritalStatus = minimal_codeableconcept('http://hl7.org/fhir/v3/MaritalStatus','S', FHIR::STU3)
        when FHIR::STU3::PlanDefinition
          resource.action.each do |a|
            a.action.each do |b|
              b.relatedAction = []
            end
          end
        when FHIR::STU3::Procedure
          resource.notDoneReason = nil if resource.notDone != true
          resource.focalDevice.each do |fd|
            code = ['implanted', 'explanted', 'manipulated'].sample
            fd.action = minimal_codeableconcept('http://hl7.org/fhir/device-action', code, FHIR::STU3)
          end
        when FHIR::STU3::Provenance
          resource.entity.each do |e|
            e.agent.each{|a| a.relatedAgentType = nil }
          end
        when FHIR::STU3::Practitioner
          resource.communication.each do |comm|
            comm.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::STU3::RelatedPerson
          resource.relationship = minimal_codeableconcept('http://hl7.org/fhir/patient-contact-relationship','family', FHIR::STU3)
        when FHIR::STU3::Questionnaire
          resource.item.each do |i|
            i.required = true
            i.item = []
            i.options = nil
            i.option = []
            if ['choice','open-choice'].include?(i.type)
              choice_a = FHIR::STU3::Questionnaire::Item::Option.new({'valueString'=>'true'})
              choice_b = FHIR::STU3::Questionnaire::Item::Option.new({'valueString'=>'false'})
              i.option = [ choice_a, choice_b ] 
            end
            if i.type=='display'
              i.required = nil
              i.repeats = nil
              i.readOnly = nil
              i.option = []
              FHIR::STU3::Questionnaire::Item::MULTIPLE_TYPES['initial'].each do |type|
                i.instance_variable_set("@initial#{type.capitalize}".to_sym, nil)
              end
            end
            i.enableWhen.each do |ew|
              ew.hasAnswer = false
              ew.hasAnswer = nil if ew.answer
            end
            i.maxLength = nil if !['boolean', 'decimal', 'integer', 'string', 'text', 'url'].include?(i.type)
          end
        when FHIR::STU3::QuestionnaireResponse
          resource.item.each do |i|
            i.item = nil
            i.answer.each {|q|q.valueBoolean = true if !q.value }
          end
        when FHIR::STU3::Range
          # validate that the low/high values in the range are correct (e.g. the low value is not higher than the high value)
          if resource.low && resource.high
            if resource.low.value > resource.high.value
              # This is the "Ruby Way" to swap two variables without using a temporary third variable
              resource.low.value,resource.high.value = resource.high.value,resource.low.value
            end
          end
          # simple quantities do not have a comparator
          resource.low.comparator = nil unless resource.low.nil?
          resource.high.comparator = nil unless resource.high.nil?
        when FHIR::STU3::ReferralRequest
          resource.requester.onBehalfOf = nil unless resource.requester.nil?
        when FHIR::STU3::Sequence
          resource.coordinateSystem = [0,1].sample

          unless resource.referenceSeq.nil?
            resource.referenceSeq.referenceSeqId = resource.referenceSeq.referenceSeqPointer = resource.referenceSeq.referenceSeqString = nil
            resource.referenceSeq.strand = [-1,1].sample unless resource.referenceSeq.strand.nil?
          end
        when FHIR::STU3::SearchParameter
          resource.type = 'reference'

        when FHIR::STU3::SampledData
          resource.origin.comparator = nil unless resource.origin.nil?
        when FHIR::STU3::Signature
          resource.type = [ minimal_coding('urn:iso-astm:E1762-95:2013','1.2.840.10065.1.12.1.18', FHIR::STU3) ]
          resource.whoUri = 'http://projectcrucible.org'
          resource.whoReference = nil
        when FHIR::STU3::Specimen
          unless resource.collection.nil?
            resource.collection.quantity.comparator = nil unless resource.collection.quantity.nil?
          end
          resource.container.each do |c|
            c.capacity = c.specimenQuantity = nil
          end
        when FHIR::STU3::Subscription
          resource.status = 'requested' if resource.id.nil?
          resource.channel.payload = 'applicaton/json+fhir'
          resource.end = nil
          resource.criteria = 'Observation?code=http://loinc.org|1975-2'
        when FHIR::STU3::Substance
          resource.instance.each do |instance|
            instance.quantity.comparator = nil unless instance.quantity.nil?
          end
        when FHIR::STU3::SupplyDelivery
          resource.type = minimal_codeableconcept('http://hl7.org/fhir/supply-item-type','medication', FHIR::STU3)
          resource.suppliedItem.quantity.comparator = nil if !resource.suppliedItem.nil? && !resource.suppliedItem.quantity.nil?
        when FHIR::STU3::SupplyRequest
          resource.category = minimal_codeableconcept('http://hl7.org/fhir/supply-kind','central', FHIR::STU3)
        when FHIR::STU3::StructureDefinition
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
              FHIR::STU3::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
                resource.snapshot.element.first.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@fixed#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
              end
            else
              FHIR::STU3::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
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
        when FHIR::STU3::StructureMap
          resource.group.each do |g|
            g.rule.each{|r|r.rule = nil}
          end
        when FHIR::STU3::Substance
          resource.ingredient.each do |ingredient|
            unless ingredient.quantity.try(:denominator).try(:comparator).nil?
              ingredient.quantity.denominator.comparator = nil
            end
            unless ingredient.quantity.try(:numerator).try(:comparator).nil?
              ingredient.quantity.numerator.comparator = nil
            end
          end
          resource.instance.each do |instance|
            unless instance.quantity.nil?
              instance.quantity.comparator = nil
            end
          end
        when FHIR::STU3::TestReport
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
        when FHIR::STU3::TestScript
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
        when FHIR::STU3::TestScript::Setup::Action::Assert
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
        when FHIR::STU3::TestScript::Setup::Action::Operation
          resource.responseId.gsub!(/[^0-9A-Za-z]/, '') if resource.responseId
          resource.sourceId.gsub!(/[^0-9A-Za-z]/, '') if resource.sourceId
          resource.targetId.gsub!(/[^0-9A-Za-z]/, '') if resource.targetId
        when FHIR::STU3::Timing
          unless resource.repeat.nil?
            resource.repeat.offset = nil if resource.repeat.when.nil?
            resource.repeat.period = resource.repeat.period * -1 if resource.repeat.period < 0
            resource.repeat.period = 1.0 if resource.repeat.period == 0
            resource.repeat.periodMax = nil if resource.repeat.period.nil?
            resource.repeat.durationMax = nil if resource.repeat.duration.nil?
            resource.repeat.countMax = nil if resource.repeat.count.nil?
            resource.repeat.duration = nil if resource.repeat.durationUnit.nil?
            resource.repeat.timeOfDay = nil unless resource.repeat.when.nil?
            resource.repeat.period = nil if resource.repeat.periodUnit.nil?
          end
        when FHIR::STU3::ValueSet
          if resource.compose
            resource.compose.include.each do |inc|
              inc.filter = nil if inc.concept
            end
            resource.compose.exclude.each do |exc|
              exc.filter = nil if exc.concept
            end
          end
        when FHIR::STU3::VisionPrescription
          resource.dispense.each do |d|
            d.duration.comparator = nil unless d.duration.nil?
          end
        when FHIR::STU3::RequestGroup::Action
          if !resource.resource.nil? && resource.action.count > 0
            if SecureRandom.random_number(2)==0
              resource.resource = nil
            else
              resource.action = []
            end
          end

        # DSTU2
        when FHIR::DSTU2::Appointment
          resource.reason = nil # minimal_codeableconcept('http://snomed.info/sct','219006', FHIR::DSTU2) # drinker of alcohol
          resource.participant.each{|p| p.type=[ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency', FHIR::DSTU2) ] }
        when FHIR::DSTU2::AppointmentResponse
          resource.participantType = [ minimal_codeableconcept('http://hl7.org/fhir/participant-type','emergency', FHIR::DSTU2) ]
        when FHIR::DSTU2::AuditEvent
          resource.object.each do |o|
            o.query=nil
            o.name = "name #{SecureRandom.base64}" if o.name.nil?
          end
        when FHIR::DSTU2::Bundle
          resource.total = nil if !['searchset','history'].include?(resource.type)
          resource.entry.each {|e|e.search=nil} if resource.type!='searchset'
          resource.entry.each {|e|e.request=nil} if !['batch','transaction','history'].include?(resource.type)
          resource.entry.each {|e|e.response=nil} if !['batch-response','transaction-response'].include?(resource.type)
          head = resource.entry.first
          if !head.nil?
            if head.request.nil? && head.response.nil? && head.resource.nil?
              if resource.type == 'document'
                head.resource = generate(FHIR::DSTU2::Composition,3)
              elsif resource.type == 'message'
                head.resource = generate(FHIR::DSTU2::MessageHeader,3)  
              else
                head.resource = generate(FHIR::DSTU2::Basic,3)                              
              end
            end
            if head.resource.nil?
              head.fullUrl = nil
            else
              rid = SecureRandom.random_number(100) + 1
              head.fullUrl = "http://projectcrucible.org/fhir/#{rid}"
              head.resource.id = "#{rid}"
            end
          end
        when FHIR::DSTU2::CarePlan
          resource.activity.each do |a|
            unless a.detail.nil?
              a.reference = nil
              a.detail.dailyAmount.comparator = nil unless a.detail.dailyAmount.nil?
              a.detail.quantity.comparator = nil unless a.detail.quantity.nil?
            end
          end
        when FHIR::DSTU2::Claim
          resource.item.each do |item|
            item.type = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV', FHIR::DSTU2)
            item.quantity.comparator = nil unless item.quantity.nil?
            item.detail.each do |detail|
              detail.type = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV', FHIR::DSTU2)
              detail.quantity.comparator = nil unless detail.quantity.nil?
              detail.subDetail.each do |sub|
                sub.type = minimal_coding('http://hl7.org/fhir/v3/ActCode','OHSINV', FHIR::DSTU2)
                sub.service = minimal_coding('http://hl7.org/fhir/ex-USCLS','1205', FHIR::DSTU2)
                sub.quantity.comparator = nil unless sub.quantity.nil?
              end
            end
          end
          resource.missingTeeth.each do |mt|
            mt.tooth = minimal_coding('http://hl7.org/fhir/ex-fdi','42', FHIR::DSTU2)
          end
        when FHIR::DSTU2::ClaimResponse
          resource.item.each do |item|
            item.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit', FHIR::DSTU2)}
            item.detail.each do |detail|
              detail.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit', FHIR::DSTU2)}
              detail.subDetail.each do |sub|
                sub.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit', FHIR::DSTU2)}
              end
            end
          end
          resource.addItem.each do |addItem|
            addItem.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit', FHIR::DSTU2)}
            addItem.detail.each do |detail|
              detail.adjudication.each{|a|a.code = minimal_coding('http://hl7.org/fhir/adjudication','benefit', FHIR::DSTU2)}
            end
          end
        when FHIR::DSTU2::Communication
          resource.payload = nil
        when FHIR::DSTU2::CommunicationRequest
          resource.payload = nil
        when FHIR::DSTU2::Composition
          resource.attester.each {|a| a.mode = ['professional']}
          resource.section.each do |section|
            section.emptyReason = nil
            section.section.each do |sub|
              sub.emptyReason = nil
              sub.section = nil
            end
          end
        when FHIR::DSTU2::ConceptMap
          if(resource.sourceUri.nil? && resource.sourceReference.nil?)
            resource.sourceReference = textonly_reference('ValueSet', FHIR::DSTU2) 
          end
          if(resource.targetUri.nil? && resource.targetReference.nil?)
            resource.targetReference = textonly_reference('ValueSet', FHIR::DSTU2) 
          end
        when FHIR::DSTU2::Conformance
          resource.fhirVersion = 'DSTU2'
          resource.format = ['xml','json']
          if resource.kind == 'capability'
            resource.implementation = nil
          elsif resource.kind == 'requirements'
            resource.implementation = nil
            resource.software = nil
          end
          resource.messaging.each{|m| m.endpoint = nil} if resource.kind != 'instance'
        when FHIR::DSTU2::Contract
          resource.actor.each do |actor|
            actor.entity = textonly_reference('Patient', FHIR::DSTU2)
          end
          resource.valuedItem.each do |valuedItem|
            valuedItem.quantity.comparator = nil unless valuedItem.quantity.nil?
          end
          resource.term.each do |term|
            term.actor.each do |actor|
              actor.entity = textonly_reference('Organization', FHIR::DSTU2)
            end
            term.group.each do |group|
              group.actor.each do |actor|
                actor.entity = textonly_reference('Organization', FHIR::DSTU2)
              end
            end
            term.valuedItem.each do |valuedItem|
              valuedItem.quantity.comparator = nil unless valuedItem.quantity.nil?
            end
          end
          resource.friendly.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::DSTU2)
          end
          resource.legal.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::DSTU2)
          end
          resource.rule.each do |f|
            f.contentAttachment = nil
            f.contentReference = textonly_reference('DocumentReference', FHIR::DSTU2)
          end
        when FHIR::DSTU2::DataElement
          resource.mapping.each do |m|
            m.identity = SecureRandom.base64 if m.identity.nil?
            m.identity.gsub!(/[^0-9A-Za-z]/, '')
          end
        when FHIR::DSTU2::DeviceComponent
          unless resource.languageCode.nil?
            resource.languageCode.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::DSTU2::DeviceMetric
          resource.measurementPeriod = nil
        when FHIR::DSTU2::DiagnosticReport
          date = DateTime.now
          resource.effectiveDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectivePeriod = nil
        when FHIR::DSTU2::DocumentManifest
          resource.content.each do |c|
            c.pAttachment = nil
            c.pReference = textonly_reference('Any', FHIR::DSTU2)
          end
        when FHIR::DSTU2::DocumentReference
          resource.docStatus = minimal_codeableconcept('http://hl7.org/fhir/composition-status','preliminary', FHIR::DSTU2)
        when FHIR::DSTU2::ElementDefinition
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
          end
          resource.binding = nil unless is_codeable
        when FHIR::DSTU2::Goal
          resource.outcome.each do |outcome|
            outcome.resultCodeableConcept = nil
            outcome.resultReference = textonly_reference('Observation', FHIR::DSTU2)
          end
        when FHIR::DSTU2::Group
          resource.member = [] if resource.actual==false
          resource.characteristic.each do |c|
            c.valueCodeableConcept = nil
            c.valueBoolean = true
            c.valueQuantity = nil
            c.valueRange = nil
          end
        when FHIR::DSTU2::ImagingObjectSelection
          resource.uid = random_oid
          resource.study.each do |study|
            study.uid = random_oid
            study.series.each do |series|
              series.uid = random_oid
              series.instance.each do |i|
                i.sopClass = random_oid
                i.uid = random_oid
              end
            end
          end
          # resource.uid = random_oid
          # index = SecureRandom.random_number(FHIR::DSTU2::ImagingObjectSelection::VALID_CODES[:title].length)
          # code = FHIR::DSTU2::ImagingObjectSelection::VALID_CODES[:title][index]
          # resource.title = minimal_codeableconcept('http://nema.org/dicom/dicm',code, FHIR::DSTU2)
          # resource.study.each do |study|
          #   study.uid = random_oid
          #   study.series.each do |series|
          #     series.uid = random_oid
          #     series.instance.each do |instance|
          #       instance.sopClass = random_oid
          #       instance.uid = random_oid
          #     end
          #   end
          # end
        when FHIR::DSTU2::ImagingStudy
          resource.uid = random_oid
          resource.series.each do |series|
            series.uid=random_oid
            series.instance.each do |instance|
              instance.uid = random_oid
              instance.sopClass = random_oid
            end
          end
        when FHIR::DSTU2::Immunization
          if resource.wasNotGiven
            resource.explanation = FHIR::DSTU2::Immunization::Explanation.new unless resource.explanation
            resource.explanation.reasonNotGiven = [ textonly_codeableconcept("reasonNotGiven #{SecureRandom.base64}", FHIR::DSTU2) ]
            resource.explanation.reason = nil
            resource.reaction = nil
          else
            resource.explanation = FHIR::DSTU2::Immunization::Explanation.new unless resource.explanation
            resource.explanation.reasonNotGiven = nil
            resource.explanation.reason = [ textonly_codeableconcept("reason #{SecureRandom.base64}", FHIR::DSTU2) ]
          end
          resource.doseQuantity.comparator = nil unless resource.doseQuantity.nil?
        when FHIR::DSTU2::ImplementationGuide
          resource.fhirVersion = 'DSTU2'
          resource.package.each do |package|
            package.resource.each do |r|
              r.sourceUri = nil
              r.sourceReference = textonly_reference('Any', FHIR::DSTU2)
            end
          end
        when FHIR::DSTU2::List
          resource.emptyReason = nil
          resource.entry.each do |entry|
            resource.mode = 'changes' if !entry.deleted.nil?
          end
        when FHIR::DSTU2::Media
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
        when FHIR::DSTU2::Medication
          if resource.product.try(:ingredient)
            resource.product.ingredient.each {|i|i.amount = nil}
          end
          resource&.package&.content&.each {|i|i.amount.comparator = nil unless i.amount.nil?}
        when FHIR::DSTU2::MedicationAdministration
          date = DateTime.now
          resource.effectiveTimeDateTime = date.strftime("%Y-%m-%dT%T.%LZ")
          resource.effectiveTimePeriod = nil
          if resource.wasNotGiven
            resource.reasonGiven = nil
          else
            resource.reasonNotGiven = nil
          end
          resource.medicationReference = textonly_reference('Medication', FHIR::DSTU2)
          resource.medicationCodeableConcept = nil
          resource.dosage.quantity.comparator = nil if !resource&.dosage&.quantity.nil?
        when FHIR::DSTU2::MedicationDispense
          resource.medicationReference = textonly_reference('Medication', FHIR::DSTU2)
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::DSTU2::MedicationOrder
          resource.medicationReference = textonly_reference('Medication', FHIR::DSTU2)
          resource.medicationCodeableConcept = nil
          resource.dosageInstruction.each {|d|d.timing = nil }
        when FHIR::DSTU2::MedicationStatement
          resource.reasonNotTaken = nil if resource.wasNotTaken != true
          resource.medicationReference = textonly_reference('Medication', FHIR::DSTU2)
          resource.medicationCodeableConcept = nil
          resource.dosage.each do |d|
            d.timing=nil
            d.quantityQuantity.comparator = nil unless d.quantityQuantity.nil?
          end
        when FHIR::DSTU2::MessageHeader
          resource.response.identifier.gsub!(/[^0-9A-Za-z]/, '') if resource.try(:response).try(:identifier)
        when FHIR::DSTU2::NamingSystem
          resource.replacedBy = nil if resource.status!='retired'
          if resource.kind == 'root'
            resource.uniqueId.each do |uid|
              uid.type='other' if ['uuid','oid'].include?(uid.type)
            end
          end
          resource.uniqueId.each do |uid|
            uid.preferred = nil
          end
        when FHIR::DSTU2::NutritionOrder
          resource.oralDiet.schedule = nil if resource.oralDiet
          resource.supplement.each do |s|
            s.schedule=nil
            s.quantity.comparator = nil unless s.quantity.nil?
          end
          if resource.enteralFormula
            resource.enteralFormula.administration = nil
            resource.enteralFormula.caloricDensity.comparator = nil unless resource.enteralFormula.caloricDensity.nil?
          end
        when FHIR::DSTU2::Observation
          resource.referenceRange.each do |referenceRange|
            referenceRange.low.comparator = nil unless referenceRange.low.nil?
            referenceRange.high.comparator = nil unless referenceRange.high.nil?
          end
          resource.component.each do |component|
            if !component.valueRange.nil?
              component.valueRange.low.comparator = nil unless component.valueRange.low.nil?
              component.valueRange.high.comparator = nil unless component.valueRange.high.nil?
            end
          end
        when FHIR::DSTU2::OperationDefinition
          resource.parameter.each do |p|
            p.binding = nil
            p.part = nil
          end
        when FHIR::DSTU2::Order
          resource.when.schedule = nil
        when FHIR::DSTU2::Patient
          resource.maritalStatus = minimal_codeableconcept('http://hl7.org/fhir/v3/MaritalStatus','S', FHIR::DSTU2)
          resource.communication.each do |communication|
            communication.language.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::DSTU2::Procedure
          resource.reasonNotPerformed = nil if resource.notPerformed != true
          resource.focalDevice.each do |fd|
            fd.action = minimal_codeableconcept('http://hl7.org/fhir/ValueSet/device-action','implanted', FHIR::DSTU2)
          end
        when FHIR::DSTU2::Provenance
          resource.entity.each do |e|
            e.agent.relatedAgent = nil if e.agent
          end
        when FHIR::DSTU2::Practitioner
          resource.communication.each do |comm|
            comm.coding.each do |c|
              c.system = 'http://tools.ietf.org/html/bcp47'
              c.code = 'en-US'
            end
          end
        when FHIR::DSTU2::RelatedPerson
          resource.relationship = minimal_codeableconcept('http://hl7.org/fhir/patient-contact-relationship','family', FHIR::DSTU2)
        when FHIR::DSTU2::Questionnaire
          resource.group.required = true
          resource.group.group = nil
          resource.group.question.each {|q|q.options = nil }
        when FHIR::DSTU2::QuestionnaireResponse
          resource.group.group = nil
          resource.group.question.each {|q|q.answer = nil }
        when FHIR::DSTU2::Subscription
          resource.status = 'requested' if resource.id.nil?
          resource.channel.payload = 'applicaton/json+fhir'
          resource.end = nil
        when FHIR::DSTU2::SupplyDelivery
          resource.type = minimal_codeableconcept('http://hl7.org/fhir/supply-item-type','medication', FHIR::DSTU2)
          resource.quantity.comparator = nil unless resource.quantity.nil?
        when FHIR::DSTU2::SupplyRequest
          resource.kind = minimal_codeableconcept('http://hl7.org/fhir/supply-kind','central', FHIR::DSTU2)
          if resource.when 
            resource.when.schedule = nil
            resource.when.code = minimal_codeableconcept('http://snomed.info/sct','20050000', FHIR::DSTU2) #biweekly
          end
        when FHIR::DSTU2::StructureDefinition
          resource.fhirVersion = 'DSTU2'
          resource.snapshot.element.first.path = resource.constrainedType if resource.snapshot && resource.snapshot.element
          resource.base = "http://hl7.org/fhir/StructureDefinition/#{resource.constrainedType}"
          is_pattern = (SecureRandom.random_number(2)==0)
          if resource.snapshot && resource.snapshot.element
            resource.snapshot.element.first.id = resource.constrainedType
            resource.snapshot.element.first.path = resource.constrainedType
            resource.snapshot.element.first.label = nil
            resource.snapshot.element.first.code = nil
            resource.snapshot.element.first.requirements = nil
            resource.snapshot.element.first.type = nil
            if is_pattern
              FHIR::DSTU2::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
                resource.snapshot.element.first.instance_variable_set("@defaultValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@fixed#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@example#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@minValue#{type.capitalize}".to_sym, nil)
                resource.snapshot.element.first.instance_variable_set("@maxValue#{type.capitalize}".to_sym, nil)
              end
            else
              FHIR::DSTU2::ElementDefinition::MULTIPLE_TYPES['defaultValue'].each do |type|
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
        when FHIR::DSTU2::Specimen
          if resource.collection
            resource.collection.quantity.comparator = nil unless resource.collection.quantity.nil?
          end
          resource.container.each do |container|
            container.capacity.comparator = nil unless container.capacity.comparator.nil?
            container.specimenQuantity.comparator = nil unless container.specimenQuantity.comparator.nil?
          end
        when FHIR::DSTU2::Substance
          resource.instance.each do |instance|
            instance.quantity.comparator = nil unless instance.quantity.nil?
          end
        when FHIR::DSTU2::TestScript
          resource.variable.each do |v|
            v.sourceId.gsub!(/[^0-9A-Za-z]/, '') if v.sourceId
            v.path = nil if v.headerField
          end
          if resource.setup
            resource.setup.metadata = nil 
            resource.setup.action.each do |a|
              a.assert = nil if a.operation
              apply_invariants!(a.operation) if a.operation
              apply_invariants!(a.assert) if a.assert
            end
          end
          resource.test.each do |test|
            test.metadata = nil
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
        # when FHIR::DSTU2::TestScript::TestScriptSetupActionAssertComponent
        #   # an assertion can only contain one of these...
        #   keys = ['contentType','headerField','minimumId','navigationLinks','path','resource','responseCode','response','validateProfileId']
        #   has_keys = []
        #   keys.each do |key|
        #     has_keys << key if resource.try(key.to_sym)
        #   end
        #   # remove all assertions except the first
        #   has_keys[1..-1].each do |key|
        #     resource.send("#{key}=",nil)
        #   end
        #   resource.sourceId.gsub!(/[^0-9A-Za-z]/, '') if resource.sourceId
        #   resource.validateProfileId.gsub!(/[^0-9A-Za-z]/, '') if resource.validateProfileId
        # when FHIR::DSTU2::TestScript::TestScriptSetupActionOperationComponent
        #   resource.responseId.gsub!(/[^0-9A-Za-z]/, '') if resource.responseId
        #   resource.sourceId.gsub!(/[^0-9A-Za-z]/, '') if resource.sourceId
        #   resource.targetId.gsub!(/[^0-9A-Za-z]/, '') if resource.targetId
        when FHIR::DSTU2::ValueSet
          if resource.compose
            resource.compose.include.each do |inc|
              inc.filter = nil if inc.concept
            end
            resource.compose.exclude.each do |exc|
              exc.filter = nil if exc.concept
            end
          end
        when FHIR::DSTU2::VisionPrescription
          resource.dispense.each do |dispense|
            dispense.duration.comparator = nil unless dispense.duration.nil?
          end
        else
          # default
        end
      end

    end
  end
end
