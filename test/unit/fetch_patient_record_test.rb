require_relative '../test_helper'
require 'webmock/test_unit'

class FetchPatientRecordTest < Test::Unit::TestCase

  TESTING_ENDPOINT = 'http://example-dstu2-server.com'
  PATIENT_XML = File.read(File.join(File.expand_path('../..', File.dirname(File.absolute_path(__FILE__))), 'fixtures', 'record', 'patient-example-f201-roel.xml'))

  def test_connectathon_8_track_two_requests

    stub_request(:get, "#{TESTING_ENDPOINT}/Patient/$everything").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'application/xml+fhir', 'Id'=>'', 'Operation'=>'fetch_patient_record',
        'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body =>
          '<Bundle xmlns="http://hl7.org/fhir">
            <id value="example"/>
            <meta>
              <versionId value="1"/>
              <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>
            <type value="searchset"/>
            <base value="http://example.com/base"/>
            <total value="0"/>
            <link>
              <relation value="self"/>
              <url value="https://example.com/base/MedicationPrescription?patient=347"/>
            </link>
            <entry>
            </entry>
          </Bundle>', :headers => {})

    stub_request(:get, "#{TESTING_ENDPOINT}/Patient/$everything?end=2012-12-31&start=2012-01-01").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'End'=>'2012-12-31', 'Format'=>'application/xml+fhir', 'Id'=>'', 'Operation'=>'fetch_patient_record',
        'Resource'=>'FHIR::Patient', 'Start'=>'2012-01-01', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body =>
          '<Bundle xmlns="http://hl7.org/fhir">
            <id value="example"/>
            <meta>
              <versionId value="1"/>
              <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>
            <type value="searchset"/>
            <base value="http://example.com/base"/>
            <total value="0"/>
            <link>
              <relation value="self"/>
              <url value="https://example.com/base/MedicationPrescription?patient=347"/>
            </link>
            <entry>
            </entry>
          </Bundle>', :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Patient").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Roelof Olaf\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31612345678\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n<communication\n>\n<coding\n>\n    <system value=\"urn:std:iso:639-1\"/>\n    <code value=\"nl-NL\"/>\n    <display value=\"Dutch\"/>\n</coding>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'2311',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'', 'Id'=>'',
        'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Patient/f201"})

    stub_request(:get, "#{TESTING_ENDPOINT}/Patient/f201/$everything").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'application/xml+fhir', 'Id'=>'f201', 'Operation'=>'fetch_patient_record',
        'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body =>
          '<Bundle xmlns="http://hl7.org/fhir">
            <id value="example"/>
            <meta>
              <versionId value="1"/>
              <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>
            <type value="searchset"/>
            <base value="http://example.com/base"/>
            <total value="0"/>
            <link>
              <relation value="self"/>
              <url value="https://example.com/base/MedicationPrescription?patient=347"/>
            </link>
            <entry>
              <resource>' + PATIENT_XML +
              '</resource>
            </entry>
          </Bundle>', :headers => {})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Patient/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:get, "#{TESTING_ENDPOINT}/Patient/f201/$everything?end=2012-12-31&start=2012-01-01").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'End'=>'2012-12-31', 'Format'=>'application/xml+fhir', 'Id'=>'f201',
        'Operation'=>'fetch_patient_record', 'Resource'=>'FHIR::Patient',
        'Start'=>'2012-01-01', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body =>
          '<Bundle xmlns="http://hl7.org/fhir">
            <id value="example"/>
            <meta>
              <versionId value="1"/>
              <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>
            <type value="searchset"/>
            <base value="http://example.com/base"/>
            <total value="0"/>
            <link>
              <relation value="self"/>
              <url value="https://example.com/base/MedicationPrescription?patient=347"/>
            </link>
            <entry>
              <resource>' + PATIENT_XML +
              '</resource>
            </entry>
          </Bundle>', :headers => {})

    stub_request(:put, "#{TESTING_ENDPOINT}/Patient/f201").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Not\"/><given value=\"Given\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"1-234-567-8901\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n<communication\n>\n<coding\n>\n    <system value=\"urn:std:iso:639-1\"/>\n    <code value=\"nl-NL\"/>\n    <display value=\"Dutch\"/>\n</coding>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'2327',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'application/xml+fhir',
        'Id'=>'f201', 'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Not\"/><given value=\"Given\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"1-234-567-8901\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n<communication\n>\n<coding\n>\n    <system value=\"urn:std:iso:639-1\"/>\n    <code value=\"nl-NL\"/>\n    <display value=\"Dutch\"/>\n</coding>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Patient/f201"})

    client = FHIR::Client.new(TESTING_ENDPOINT)

    results = Crucible::Tests::Executor.new(client).execute('TrackTwoTest')

    assert !results.blank?, 'Failed to execute TrackTwoTest.'
  end

end
