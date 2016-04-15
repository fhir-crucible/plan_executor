module Crucible
  module Tests
    class RobustSearchTest < BaseSuite

      def id
        'Search002'
      end

      def description
        'Deeper testing of search capabilities.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # Create a patient with gender:missing
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.minimal_patient
        @patient.identifier = [FHIR::Identifier.new]
        @patient.identifier[0].value = SecureRandom.urlsafe_base64
        result = @client.create(@patient)
        @patient_id = result.id

        # read all the patients
        @read_entire_feed=true
        @client.use_format_param = true
        reply = @client.read_feed(FHIR::Patient)
        @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        @total_count = 0
        @entries = []

        while reply != nil && !reply.resource.nil?
          @total_count += reply.resource.entry.size
          @entries += reply.resource.entry
          reply = @client.next_page(reply)
          @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        end

        # create a condition matching the first patient
        @condition = ResourceGenerator.generate(FHIR::Condition,1)
        @condition.patient = ResourceGenerator.generate(FHIR::Reference)
        @condition.patient.id = @entries.try(:[],0).try(:resource).try(:xmlId)
        options = {
          :id => @entries.try(:[],0).try(:resource).try(:xmlId),
          :resource => @entries.try(:[],0).try(:resource).try(:class)
        }
        @condition.patient.reference = @client.resource_url(options)
        reply = @client.create(@condition)
        @condition_id = reply.id

        # create some observations
        @obs_a = create_observation(4.12345)
        @obs_b = create_observation(4.12346)
        @obs_c = create_observation(4.12349)
        @obs_d = create_observation(5.12)
        @obs_e = create_observation(6.12)
      end

      def create_observation(value)
        observation = FHIR::Observation.new
        observation.status = 'preliminary'
        code = FHIR::Coding.new
        code.system = 'http://loinc.org'
        code.code = '2164-2'
        observation.code = FHIR::CodeableConcept.new
        observation.code.coding = [ code ]
        observation.valueQuantity = FHIR::Quantity.new
        observation.valueQuantity.system = 'http://unitofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.unit = 'mmol'
        body = FHIR::Coding.new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySite = FHIR::CodeableConcept.new
        observation.bodySite.coding = [ body ]
        reply = @client.create(observation)
        reply.id
      end

      def teardown
        @client.use_format_param = false
        @client.destroy(FHIR::Patient, @patient_id) if @patient_id
        @client.destroy(FHIR::Condition, @condition_id) if @condition_id
        @client.destroy(FHIR::Observation, @obs_a) if @obs_a
        @client.destroy(FHIR::Observation, @obs_b) if @obs_b
        @client.destroy(FHIR::Observation, @obs_c) if @obs_c
        @client.destroy(FHIR::Observation, @obs_d) if @obs_d
        @client.destroy(FHIR::Observation, @obs_e) if @obs_e
      end

    [true,false].each do |flag|  
      action = 'GET'
      action = 'POST' if flag

      test "SR01#{action[0]}","Patient Matching using an MPI (#{action})" do
        metadata {
          links "#{BASE_SPEC_LINK}/patient.html#match"
          validates resource: 'Patient', methods: ['search']
          validates extensions: ['extensions']
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_query' => 'mpi',
              'given' => @patient.name[0].given[0]
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)        
 
        has_mpi_data = true
        has_score = true
        reply.resource.entry.each do |entry|
          has_score = has_score && entry.try(:search).try(:score)
          entry_has_mpi_data = false
          if entry.search
            entry.search.extension.each do |e|
              if (e.url=='http://hl7.org/fhir/StructureDefinition/patient-mpi-match' && e.value && ['certain','probable','possible','certainly-not'].include?(e.valueCode))
                entry_has_mpi_data = true
              end
            end
          end
          has_mpi_data = has_mpi_data && entry_has_mpi_data
        end
        assert( has_score && has_mpi_data, "Every Patient Matching result requires a score and 'patient-mpi-match' extension.", reply.body)
      end

# Search Parameter Types    
#   Number
#   Date/DateTime
#   String
#   Token
#   Reference
#   Composite
#   Quantity
#   URI
# Parameters for all resources
#   _id
#   _lastUpdated
#   _tag
#   _profile
#   _security
#   _text
#   _content
#   _list
#   _query
# Search result parameters
#   _sort
#   _count
#   _include
#   _revinclude
#   _summary
#   _elements
#   _contained
#   _containedType
    end # EOF [true,false].each

    end
  end
end
