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
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        @records = {}

        patient = @resources.load_fixture('patient/patient-uslab-example1.xml')
        provider = @resources.load_fixture('practitioner/pract-uslab-example1.xml')
        performer = @resources.load_fixture('practitioner/pract-uslab-example3.xml')
        organization = @resources.load_fixture('organization/org-uslab-example3.xml')

        specimen_100 = @resources.load_fixture('specimen/spec-100.xml')
        specimen_400 = @resources.load_fixture('specimen/spec-400.xml')
        specimen_uslab = @resources.load_fixture('specimen/spec-400.xml')

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
        create_procedure_request('diagnostic_request/do-100.xml', :diag_order_1)
        create_procedure_request('diagnostic_request/do-200.xml', :diag_order_2, :spec_uslab)
        create_procedure_request('diagnostic_request/do-300.xml', :diag_order_3, :spec_uslab)
        create_procedure_request('diagnostic_request/do-400.xml', :diag_order_4, :spec_400)
      end

      # The `Order` resource disappeared in STU3
      # test 'C12T11_2', 'Create an Order referencing the ProcedureRequest' do
      #   metadata {
      #     links "#{REST_SPEC_LINK}#create"
      #     links "http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_1_Order_a_new_lab_test"
      #     requires resource: 'Patient', methods: ['read']
      #     requires resource: 'Practitioner', methods: ['read']
      #     requires resource: 'ProcedureRequest', methods: ['read']
      #     requires resource: 'Order', methods: ['create', 'delete']
      #     validates resource: 'Order', methods: ['create', 'delete']
      #   }
      #   create_order('order/order-100.xml', :order_1, :diag_order_1)
      #   create_order('order/order-200.xml', :order_2, :diag_order_2)
      #   create_order('order/order-300.xml', :order_3, :diag_order_3)
      #   create_order('order/order-400.xml', :order_4, :diag_order_4)
      # end

      # The `OrderResponse` resource disappeared in STU3
      # test 'C12T11_3', 'Create an OrderResponse referencing the Order' do
      #   metadata {
      #     links "#{REST_SPEC_LINK}#create"
      #     links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_2_Accept_new_lab_orders'
      #     requires resource: 'Patient', methods: ['read']
      #     requires resource: 'Practitioner', methods: ['read']
      #     requires resource: 'ProcedureRequest', methods: ['read']
      #     requires resource: 'Order', methods: ['read']
      #     requires resource: 'OrderResponse', methods: ['create']
      #     validates resource: 'OrderResponse', methods: ['create']
      #   }

      #   create_order_response('order_response/ordresp-100.xml', :order_response_1, @records[:order_1])
      #   create_order_response('order_response/ordresp-200.xml', :order_response_2, @records[:order_2])
      #   create_order_response('order_response/ordresp-300.xml', :order_response_3, @records[:order_3])
      #   create_order_response('order_response/ordresp-400.xml', :order_response_4, @records[:order_4])
      # end

      test 'C12T11_4', 'Submit DiagnosticReport, Specimen, and Observation resources' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{REST_SPEC_LINK}#read"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_3_Fulfill_Lab_Order'
          requires resource: 'ProcedureRequest', methods: ['read']
          requires resource: 'DiagnosticReport', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'Specimen', methods: ['read']
          validates resource: 'OrderResponse', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'DiagnosticReport', methods: ['create']
        }

        # Skips if diagnostic reports do not exist
        skip 'Diagnostic Order 1 not successfully created in startup.' if @records[:diag_order_1].nil?
        skip 'Diagnostic Order 2 not successfully created in startup.' if @records[:diag_order_2].nil?
        skip 'Diagnostic Order 3 not successfully created in startup.' if @records[:diag_order_3].nil?
        skip 'Diagnostic Order 4 not successfully created in startup.' if @records[:diag_order_4].nil?

        create_diagnostic_report(:spec_100, ['observation/obs-100.xml', 'observation/obs-101.xml'], 'diagnostic_report/dr-100.xml', :diag_report_1, @records[:diag_order_1])
        create_diagnostic_report(:spec_uslab, ['observation/obs-200.xml'], 'diagnostic_report/dr-200.xml', :diag_report_2, @records[:diag_order_2])
        create_diagnostic_report(:spec_uslab, ['observation/obs-300.xml', 'observation/obs-301.xml', 'observation/obs-302.xml', 'observation/obs-303.xml', 'observation/obs-304.xml'], 'diagnostic_report/dr-300.xml', :diag_report_3, @records[:diag_order_3])
        create_diagnostic_report(:spec_400, ['observation/obs-400.xml', 'observation/obs-401.xml', 'observation/obs-402.xml', 'observation/obs-403.xml', 'observation/obs-404.xml', 'observation/obs-405.xml', 'observation/obs-406.xml', 'observation/obs-407.xml', 'observation/obs-408.xml'], 'diagnostic_report/dr-400.xml', :diag_report_4, @records[:diag_order_4])
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
        diag_order = @resources.load_fixture(fixture_path)
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
        diag_report = @resources.load_fixture(diagnostic_report_fixture_path)
        diag_report.subject = @records[:patient].to_reference
        diag_report.issued = DateTime.now.iso8601
        diag_report.effectiveDateTime = DateTime.now.iso8601
        diag_report.performer = [ FHIR::DiagnosticReport::Performer.new ]
        diag_report.performer.first.actor = @records[:performer].to_reference
        diag_report.basedOn = [diag_order.to_reference]
        diag_report.specimen = [@records[specimen_name].to_reference]
        diag_report.result = []

        observation_fixture_paths.each_with_index do |obs, index|
          observation = @resources.load_fixture(obs)
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
