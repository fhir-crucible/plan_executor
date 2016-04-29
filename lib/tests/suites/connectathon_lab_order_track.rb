module Crucible
  module Tests
    class ConnectathonLabOrderTrackTest < BaseSuite

      def id
        'ConnectathonLabOrderTrackTest'
      end

      def description
        'Connectathon Lab Order Track focuses on DiagnosticOrder, Order, Observation and Specimen.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        @records = {}

        patient = @resources.load_fixture('patient/patient-uslab-example1.xml')
        provider = @resources.load_fixture('practitioner/pract-uslab-example1.xml')
        performer = @resources.load_fixture('practitioner/pract-uslab-example3.xml')
        organization = @resources.load_fixture('organization/org-uslab-example3.xml')

        # Create our reference patient
        create_object(patient, :patient)

        # Create our reference provider (Order Orderer)
        create_object(provider, :provider)

        # Create our reference performer (Order performer)
        create_object(performer, :performer)

        # Create the Organization all of these belong to
        create_object(organization, :organization)
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
      end

      test 'C12T11_1', 'Create a DiagnosticOrder' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_1_Order_a_new_lab_test"
          requires resource: 'Patient', methods: ['create', 'delete']
          requires resource: 'Practitioner', methods: ['create', 'delete']
          requires resource: 'DiagnosticOrder', methods: ['create']
          validates resource: 'DiagnosticOrder', methods: ['create']
        }
        create_diagnostic_order('diagnostic_order/do-100.xml', :diag_order_1)
        create_diagnostic_order('diagnostic_order/do-200.xml', :diag_order_2)
        create_diagnostic_order('diagnostic_order/do-300.xml', :diag_order_3)
        create_diagnostic_order('diagnostic_order/do-400.xml', :diag_order_4)

      end

      test 'C12T11_2', 'Create an Order referencing the DiagnosticOrder' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_1_Order_a_new_lab_test"
          requires resource: 'Patient', methods: ['read']
          requires resource: 'Practitioner', methods: ['read']
          requires resource: 'DiagnosticOrder', methods: ['read']
          requires resource: 'Order', methods: ['create']
          validates resource: 'Order', methods: ['create']
        }
        create_order('order/order-100.xml', :order_1)
        create_order('order/order-200.xml', :order_2)
        create_order('order/order-300.xml', :order_3)
        create_order('order/order-400.xml', :order_4)
      end

      test 'C12T11_3', 'Create an OrderResponse referencing the Order' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_2_Accept_new_lab_orders'
          requires resource: 'Patient', methods: ['read']
          requires resource: 'Practitioner', methods: ['read']
          requires resource: 'DiagnosticOrder', methods: ['read']
          requires resource: 'Order', methods: ['read']
          requires resource: 'OrderResponse', methods: ['create']
          validates resource: 'OrderResponse', methods: ['create']
        }

        create_order_response('order_response/ordresp-100.xml', :order_response_1, @records[:order_1])
        create_order_response('order_response/ordresp-200.xml', :order_response_2, @records[:order_2])
        create_order_response('order_response/ordresp-300.xml', :order_response_3, @records[:order_3])
        create_order_response('order_response/ordresp-400.xml', :order_response_4, @records[:order_4])
      end

      test 'C12T11_4', 'Submit DiagnosticReport, Specimen and Observation resources' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{REST_SPEC_LINK}#read"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_3_Fulfill_Lab_Order'
          requires resource: 'DiagnosticOrder', methods: ['read']
          requires resource: 'DiagnosticReport', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'Specimen', methods: ['create']
          validates resource: 'OrderResponse', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'DiagnosticReport', methods: ['create']
        }

        create_diagnostic_report('specimen/spec-100.xml', ['observation/obs-100.xml', 'observation/obs-101.xml'], 'diagnostic_report/dr-100.xml', :diag_report_1, @records[:diag_order_1])
        create_diagnostic_report('specimen/spec-uslab-example1.xml', ['observation/obs-200.xml'], 'diagnostic_report/dr-200.xml', :diag_report_2, @records[:diag_order_2])
        create_diagnostic_report('specimen/spec-uslab-example1.xml', ['observation/obs-300.xml', 'observation/obs-301.xml', 'observation/obs-302.xml', 'observation/obs-303.xml', 'observation/obs-304.xml'], 'diagnostic_report/dr-300.xml', :diag_report_3, @records[:diag_order_3])
        create_diagnostic_report('specimen/spec-400.xml', ['observation/obs-400.xml', 'observation/obs-401.xml', 'observation/obs-402.xml', 'observation/obs-403.xml', 'observation/obs-404.xml', 'observation/obs-405.xml', 'observation/obs-406.xml', 'observation/obs-407.xml', 'observation/obs-408.xml'], 'diagnostic_report/dr-400.xml', :diag_report_4, @records[:diag_order_4])

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

      test 'C12T11_6', 'Update DiagnosticOrder' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{REST_SPEC_LINK}#update"
          links 'http://wiki.hl7.org/index.php?title=201605_LabOrder#Step_4_Receive_Lab_Results'
          requires resource: 'DiagnosticOrder', methods: ['read', 'update']
          validates resource: 'DiagnosticOrder', methods: ['read', 'update']
        }
        update_diagnostic_order(:diag_order_1)
        update_diagnostic_order(:diag_order_2)
        update_diagnostic_order(:diag_order_3)
        update_diagnostic_order(:diag_order_4)
      end

      private

      def create_order(fixture_path, order_name)
        order = @resources.load_fixture(fixture_path)
        order.date = DateTime.now.iso8601
        order.subject = @records[:patient].to_reference
        order.source = @records[:provider].to_reference

        create_object(order, order_name)
      end

      def create_diagnostic_order(fixture_path, order_name)
        diag_order = @resources.load_fixture(fixture_path)
        diag_order.subject = @records[:patient].to_reference
        diag_order.orderer = @records[:provider].to_reference

        create_object(diag_order, order_name)
      end

      def create_order_response(fixture_path, response_name, reference_order)
        order_response = @resources.load_fixture(fixture_path)
        order_response.date = DateTime.now.iso8601
        order_response.request = reference_order.to_reference
        order_response.who = @records[:organization].to_reference

        create_object(order_response, response_name)
      end

      def create_diagnostic_report(specimen_fixture_path, observation_fixture_paths, diagnostic_report_fixture_path, dr_name, diag_order)
        specimen = @resources.load_fixture(specimen_fixture_path)
        specimen.subject = @records[:patient].to_reference
        specimen_name = "#{dr_name}_specimen".to_sym
        create_object(specimen, specimen_name)

        diag_report = @resources.load_fixture(diagnostic_report_fixture_path)
        diag_report.subject = @records[:patient].to_reference
        diag_report.issued = DateTime.now.iso8601
        diag_report.effectiveDateTime = DateTime.now.iso8601
        diag_report.performer = @records[:performer].to_reference
        diag_report.request << diag_order.to_reference
        diag_report.specimen << @records[specimen_name].to_reference

        observation_fixture_paths.each_with_index do |obs, index|
          observation = @resources.load_fixture(obs)
          observation.specimen = specimen.to_reference
          observation.subject = @records[:patient].to_reference
          observation_name = "#{dr_name}_observation_{index}".to_sym
          create_object(observation, observation_name)
          diag_report.result << @records[observation_name].to_reference
        end

        create_object(diag_report, dr_name)
      end

      def get_diagnostic_report(dr_name)
        reply = @client.read FHIR::DiagnosticReport, @records[dr_name].id
        assert_response_ok(reply)

        assert reply.resource.equals?(@records[dr_name], ['text', 'meta', 'presentedForm', 'extension']), "Diagnostic Report #{dr_name.to_s} doesn't match retrieved Diagnostic Report"
      end

      def update_diagnostic_order(order_name)
        reply = @client.read FHIR::DiagnosticOrder, @records[order_name].id
        assert_response_ok(reply)

        assert reply.resource.equals?(@records[order_name], ['text', 'meta', 'presentedForm', 'extension']), "Reply did not match #{@records[order_name]}"

        assert reply.resource.status == 'requested'

        @records[order_name].status = 'completed'

        reply = @client.update @records[order_name], @records[order_name].id
        assert_response_ok(reply)

        reply = @client.read FHIR::DiagnosticOrder, @records[order_name].id
        assert_response_ok(reply)

        assert reply.resource.equals?(@records[order_name], ['text', 'meta', 'presentedForm', 'extension']), "Reply did not match #{@records[order_name]}"

        assert reply.resource.status == 'completed'

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
