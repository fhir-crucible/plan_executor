module Crucible
  module Tests
    class USCoreResourceGenerator < ResourceGenerator

      def self.patient(identifier='0',name='Name')
        resource = minimal_patient(identifier,name)
        # resource.identifier = [ minimal_identifier(identifier) ]
        # resource.name = [ minimal_humanname(name) ]
        resource.meta.profile = ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient']
        # US Core must supports and US Core extensions
        resource.active = true
        resource.telecom = [ contact_point ]
        resource.gender = 'unknown'
        resource.birthDate = DateTime.now.strftime("%Y-%m-%d")
        resource.deceasedBoolean = false
        resource.address = [ address ]
        resource.maritalStatus = minimal_codeableconcept('http://hl7.org/fhir/v3/MaritalStatus','S')
        resource.multipleBirthBoolean = false
        resource.contact = [ patient_contact ]
        resource.communication = [ patient_communication ]
        # resource.careProvider = [ FHIR::Reference.new ] # reference to US Core-Organization or US Core-Pract
        # resource.careProvider.first.display = 'US Core Organization or Practitioner'
        resource.managingOrganization = FHIR::Reference.new # reference to US Core-Organization
        resource.managingOrganization.display = 'US Core Organization'
        resource.extension = []
        resource.extension << make_extension('http://hl7.org/fhir/us/core/StructureDefinition/us-core-race','CodeableConcept',minimal_codeableconcept('http://hl7.org/fhir/v3/Race','2106-3'))
        resource.extension << make_extension('http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity','CodeableConcept',minimal_codeableconcept('http://hl7.org/fhir/v3/Ethnicity','2186-5'))
        resource.extension << make_extension('http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName','String','Liberty')
        resource.extension << make_extension('http://hl7.org/fhir/StructureDefinition/birthPlace','Address',address)
        resource
      end

      # Patient.name
      # Sex Gender  Patient.gender
      # Date of Birth Date of Birth Patient.birthDate
      # Race  Race  Patient.extension(us-core-race)
      # Ethnicity Ethnicity Patient.extension(us-core-ethnicity)
      # Preferred Language  Preferred Language  Patient.communication.preferred
      # Patient Identifiers Patient.identifier
      # Multiple Birth Indicator  Patient.multipleBirthBoolean
      # Birth Order Patient.multipleBirthInteger
      # Mother's Maiden Name  Patient.extension(patient-mothers-maiden-name)
      # Address Patient.address
      # Telephone Patient.telecom
      # Marital Status  Patient.maritalStatus
      # Birth Place Patient.extension(birthplace)
      # Religious Affiliation Patient.extension(religion)
      # Guardian  Patient.contact

      def self.contact_point
        resource = FHIR::ContactPoint.new
        resource.system = 'phone'
        resource.value = '1-800-555-1212'
        resource.use = 'work'
        resource
      end

      def self.address
        resource = FHIR::Address.new
        resource.line = ['Statue of Liberty National Monument']
        resource.city = 'New York'
        resource.state = 'NY'
        resource.postalCode = '10004'
        resource.country = 'USA'
        resource
      end

      def self.patient_contact
        resource = FHIR::Patient::Contact.new
        resource.relationship = [ minimal_codeableconcept('http://hl7.org/fhir/patient-contact-relationship','parent'), minimal_codeableconcept('http://hl7.org/fhir/patient-contact-relationship','emergency') ]
        resource.name = minimal_humanname('Mom')
        resource.telecom = [ contact_point ]
        resource.address = address
        resource
      end

      def self.patient_communication
        resource = FHIR::Patient::Communication.new
        resource.language = minimal_codeableconcept('http://tools.ietf.org/html/bcp47','en-US')
        resource
      end

      def self.make_extension(url,type,value)
        extension = FHIR::Extension.new
        extension.url = url
        extension.method("value#{type}=".to_sym).call(value)
        extension
      end

    end
  end
end
