module Crucible
  module Tests
    class ConnectathonLabOrderTrackTest < BaseSuite

      def id
        'ConnectathonLabOrderTrackTest'
      end

      def description
        'Connectathon Lab Order Track focuses on ProcedureRequest, Observation, Specimen, and DiagnosticReport.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        # @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @resources = Crucible::Generator::Resources.new(fhir_version)

        @records = {}

        patient = @resources.patient_uslab1
        provider = @resources.practitioner_uslab1
        performer = @resources.practitioner_uslab3
        organization = @resources.organization_uslab3

        specimen_100 = @resources.specimen_100
        specimen_400 = @resources.specimen_400
        specimen_uslab = @resources.specimen_400

        # Create our reference patient
        create_object(patient, :patient)

        # Create our reference provider (Order Orderer)
        create_object(provider, :provider)

        # Create our reference performer (Order performer)
        create_object(performer, :performer)

        # Create the Organization all of these belong to
        create_object(organization, :organization)

        specimen_100.subject = @records[:patient].to_reference
        create_object(specimen_100, :spec_100)

        specimen_400.subject = @records[:patient].to_reference
        create_object(specimen_400, :spec_400)

        specimen_uslab.subject = @records[:patient].to_reference
        create_object(specimen_uslab, :spec_uslab)
      end

      def teardown
        resourceType = ['DiagnosticReport','ProcedureRequest','Observation','Specimen','Practitioner','Patient','Organization']
        resourceType.each do |type|
          @records.each_value do |value|
            @client.destroy(value.class, value.id) if value.resourceType==type
          end
        end
      end

      test 'C12T11_1', 'Create a ProcedureRequest' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_1_Order_a_new_lab_test"
          requires resource: 'Patient', methods: ['create', 'delete']
          requires resource: 'Practitioner', methods: ['create', 'delete']
          requires resource: 'ProcedureRequest', methods: ['create']
          validates resource: 'ProcedureRequest', methods: ['create']
        }
        create_procedure_request('diagnostic_request/do-100', :diag_order_1)
        create_procedure_request('diagnostic_request/do-200', :diag_order_2, :spec_uslab)
        create_procedure_request('diagnostic_request/do-300', :diag_order_3, :spec_uslab)
        create_procedure_request('diagnostic_request/do-400', :diag_order_4, :spec_400)
      end

      test 'C12T11_4', 'Submit DiagnosticReport, Specimen, and Observation resources' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{REST_SPEC_LINK}#read"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_3_Fulfill_Lab_Order'
          requires resource: 'ProcedureRequest', methods: ['read']
          requires resource: 'DiagnosticReport', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'Specimen', methods: ['read']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'DiagnosticReport', methods: ['create']
        }

        # Skips if diagnostic reports do not exist
        skip 'Diagnostic Order 1 not successfully created in startup.' if @records[:diag_order_1].nil?
        skip 'Diagnostic Order 2 not successfully created in startup.' if @records[:diag_order_2].nil?
        skip 'Diagnostic Order 3 not successfully created in startup.' if @records[:diag_order_3].nil?
        skip 'Diagnostic Order 4 not successfully created in startup.' if @records[:diag_order_4].nil?

        create_diagnostic_report(:spec_100, ['observation/obs-100', 'observation/obs-101'], 'diagnostic_report/dr-100', :diag_report_1, @records[:diag_order_1])
        create_diagnostic_report(:spec_uslab, ['observation/obs-200'], 'diagnostic_report/dr-200', :diag_report_2, @records[:diag_order_2])
        create_diagnostic_report(:spec_uslab, ['observation/obs-300', 'observation/obs-301', 'observation/obs-302', 'observation/obs-303', 'observation/obs-304'], 'diagnostic_report/dr-300', :diag_report_3, @records[:diag_order_3])
        create_diagnostic_report(:spec_400, ['observation/obs-400', 'observation/obs-401', 'observation/obs-402', 'observation/obs-403', 'observation/obs-404', 'observation/obs-405', 'observation/obs-406', 'observation/obs-407', 'observation/obs-408'], 'diagnostic_report/dr-400', :diag_report_4, @records[:diag_order_4])
      end

      test 'C12T11_5', 'Retrieve DiagnosticReport' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_4_Receive_Lab_Results'
          requires resource: 'DiagnosticReport', methods: ['read']
          validates resource: 'DiagnosticReport', methods: ['read']
        }

        get_diagnostic_report(:diag_report_1)
        get_diagnostic_report(:diag_report_2)
        get_diagnostic_report(:diag_report_3)
        get_diagnostic_report(:diag_report_4)
      end

      test 'C12T11_6', 'Update ProcedureRequest' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_4_Receive_Lab_Results'
          requires resource: 'ProcedureRequest', methods: ['read', 'update']
          validates resource: 'ProcedureRequest', methods: ['read', 'update']
        }
        update_diagnostic_request(:diag_order_1)
        update_diagnostic_request(:diag_order_2)
        update_diagnostic_request(:diag_order_3)
        update_diagnostic_request(:diag_order_4)
      end

      private

      # The `Order` resource disappeared in STU3
      # def create_order(fixture_path, order_name, diag_order_name)
      #   order = @resources.load_fixture(fixture_path)
      #   order.date = DateTime.now.iso8601
      #   order.subject = @records[:patient].to_reference
      #   order.source = @records[:provider].to_reference
      #   order.detail = @records[diag_order_name].to_reference

      #   create_object(order, order_name)
      # end

      def create_procedure_request(fixture_path, order_name, specimen_name = nil)
        diag_order = @resources.load_fixture(fixture_path, :xml)
        diag_order.subject = @records[:patient].to_reference
        diag_order.requester = FHIR::ProcedureRequest::Requester.new unless diag_order.requester
        diag_order.requester.agent = @records[:provider].to_reference
        diag_order.supportingInfo = [@records[specimen_name].to_reference] if specimen_name

        create_object(diag_order, order_name)
      end

      # The `OrderResponse` resource disappeared in STU3
      # def create_order_response(fixture_path, response_name, reference_order)
      #   order_response = @resources.load_fixture(fixture_path)
      #   order_response.date = DateTime.now.iso8601
      #   order_response.request = reference_order.to_reference
      #   order_response.who = @records[:organization].to_reference

      #   create_object(order_response, response_name)
      # end

      def create_diagnostic_report(specimen_name, observation_fixture_paths, diagnostic_report_fixture_path, dr_name, diag_order)
        diag_report = @resources.load_fixture(diagnostic_report_fixture_path, :xml)
        diag_report.subject = @records[:patient].to_reference
        diag_report.issued = DateTime.now.iso8601
        diag_report.effectiveDateTime = DateTime.now.iso8601
        diag_report.performer = [ FHIR::DiagnosticReport::Performer.new ]
        diag_report.performer.first.actor = @records[:performer].to_reference
        diag_report.basedOn = [diag_order.to_reference]
        diag_report.specimen = [@records[specimen_name].to_reference]
        diag_report.result = []

        observation_fixture_paths.each_with_index do |obs, index|
          observation = @resources.load_fixture(obs, :xml)
          observation.specimen = @records[specimen_name].to_reference
          observation.subject = @records[:patient].to_reference
          observation.performer = @records[:performer].to_reference
          observation_name = "#{dr_name}_observation_#{index}".to_sym
          create_object(observation, observation_name)
          diag_report.result << @records[observation_name].to_reference
        end

        create_object(diag_report, dr_name)
      end

      def get_diagnostic_report(dr_name)
        assert @records[dr_name], "No DiagnosticReport with that name present"
        reply = @client.read FHIR::DiagnosticReport, @records[dr_name].id
        assert_response_ok(reply)
        assert reply.resource.equals?(@records[dr_name], ['text', 'meta', 'presentedForm', 'extension']), "DiagnosticReport/#{@records[dr_name].id} doesn't match retrieved DiagnosticReport. Mismatched fields: #{reply.resource.mismatch(@records[dr_name], ['text', 'meta', 'presentedForm', 'extension'])}"
      end

      def update_diagnostic_request(order_name)
        assert @records[order_name], "No ProcedureRequest with that name present"
        
        reply = @client.read FHIR::ProcedureRequest, @records[order_name].id
        
        assert_response_ok(reply)
        assert reply.resource.equals?(@records[order_name], ['text', 'meta', 'presentedForm', 'extension']), "Reply did not match ProcedureRequest/#{@records[order_name].id}. Mismatched fields: #{reply.resource.mismatch(@records[order_name], ['text', 'meta', 'presentedForm', 'extension'])}"
        assert reply.resource.status == 'active', 'ProcedureRequest status should be active.'

        @records[order_name].status = 'completed'
        reply = @client.update @records[order_name], @records[order_name].id
        
        assert_response_ok(reply)

        reply = @client.read FHIR::ProcedureRequest, @records[order_name].id
        
        assert_response_ok(reply)
        assert reply.resource.equals?(@records[order_name], ['text', 'meta', 'presentedForm', 'extension']), "Reply did not match #{@records[order_name]}. Mismatched fields: #{reply.resource.mismatch(@records[order_name], ['text', 'meta', 'presentedForm', 'extension'])}"
        assert reply.resource.status == 'completed', 'ProcedureRequest status should have updated to completed.'
      end

      def create_object(obj, obj_sym)
        obj.id = nil
        reply = @client.create obj
        assert_response_ok(reply)
        obj.id = reply.id
        @records[obj_sym] = obj

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end
    end
  end
end
