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
        # Create a patient
        patient = Crucible::Generator::Resources.new.minimal_patient
        patient.identifier = [FHIR::Identifier.new]
        patient.identifier[0].value = SecureRandom.urlsafe_base64
        ignore_client_exception { @patient = FHIR::Patient.create(patient) }
        assert_resource_type @client.reply, FHIR::Patient
        assert @patient, "Response code #{@client.reply.code} on patient creation."
      end

      def teardown
        ignore_client_exception { @patient.destroy }
      end

      test "SR01","Patient Matching using an MPI" do
        metadata {
          links "#{BASE_SPEC_LINK}/patient.html#match"
          validates resource: 'Patient', methods: ['$match']
          validates extensions: ['extensions']
        }
        match_patient = Crucible::Generator::Resources.new.minimal_patient
        match_patient.identifier = nil
        reply = @client.match(match_patient)
        assert_response_ok(reply)
        assert_bundle_response(reply)        
 
        has_mpi_data = true
        has_score = true
        reply.resource.entry.each do |entry|
          has_score = has_score && entry.try(:search).try(:score)
          entry_has_mpi_data = false
          if entry.search
            entry.search.extension.each do |e|
              if (e.url=='http://hl7.org/fhir/StructureDefinition/match-grade' && e.value && ['certain','probable','possible','certainly-not'].include?(e.valueCode))
                entry_has_mpi_data = true
              end
            end
          end
          has_mpi_data = has_mpi_data && entry_has_mpi_data
        end
        assert( has_score && has_mpi_data, "Every Patient Matching result requires a score and 'match-grade' extension.", reply.body)
      end
    end
  end
end
