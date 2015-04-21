require_relative '../test_helper'
require 'webmock/test_unit'

class FetchPatientRecordTest < Test::Unit::TestCase

  TESTING_ENDPOINT = 'http://example-dstu2-server.com'
  ROOT_PATH = File.expand_path('../..', File.dirname(File.absolute_path(__FILE__)))
  CONDITION_1_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'condition-example-f201-fever.xml'))
  CONDITION_2_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'condition-example-f205-infection.xml'))
  DIAGNOSTICREPORT_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'diagnosticreport-example-f201-brainct.xml'))
  ENCOUNTER_1_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'encounter-example-f201-20130404.xml'))
  ENCOUNTER_2_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'encounter-example-f202-20130128.xml'))
  OBSERVATION_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'observation-example-f202-temperature.xml'))
  ORGANIZATION_1_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'organization-example-f201-aumc.xml'))
  ORGANIZATION_2_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'organization-example-f203-bumc.xml'))
  PATIENT_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'patient-example-f201-roel.xml'))
  PRACTITIONER_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'practitioner-example-f201-ab.xml'))
  PROCEDURE_XML = File.read(File.join(ROOT_PATH, 'fixtures', 'record', 'procedure-example-f201-tpf.xml'))

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
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Roelof Olaf\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31612345678\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n    <communication\n>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'2150',
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
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Not\"/><given value=\"Given\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"1-234-567-8901\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n    <communication\n>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'2166',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'application/xml+fhir',
        'Id'=>'f201', 'Resource'=>'FHIR::Patient', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Patient\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"BSN\"/>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.6.3\"/>\n    <value value=\"123456789\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Roel\"/>\n    <family value=\"Bor\"/>\n    <given value=\"Not\"/><given value=\"Given\"/>\n    <prefix value=\"Drs.\"/>\n    <suffix value=\"PDEng.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"1-234-567-8901\"/>\n    <use value=\"mobile\"/>\n</telecom>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n    <gender value=\"male\"/>\n    <birthDate value=\"1960-03-13\"/>\n    <deceasedBoolean value=\"false\"/>\n<address\n>\n    <use value=\"home\"/>\n    <line value=\"Bos en Lommerplein 280\"/>\n    <city value=\"Amsterdam\"/>\n    <postalCode value=\"1055RW\"/>\n    <country value=\"NLD\"/>\n</address>\n<maritalStatus\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"36629006\"/>\n    <display value=\"Legally married\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v3/MaritalStatus\"/>\n    <code value=\"M\"/>\n</coding>\n</maritalStatus>\n    <multipleBirthBoolean value=\"false\"/>\n<photo\n>\n    <contentType value=\"image/jpeg\"/>\n    <url value=\"binary/@f006\"/>\n</photo>\n    <contact\n>\n<relationship\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"127850001\"/>\n    <display value=\"Wife\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/patient-contact-relationship\"/>\n    <code value=\"partner\"/>\n</coding>\n</relationship>\n<name\n>\n    <use value=\"usual\"/>\n    <text value=\"Ariadne Bor-Jansma\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31201234567\"/>\n    <use value=\"home\"/>\n</telecom>\n</contact>\n<communication\n>\n<coding\n>\n    <system value=\"urn:std:iso:639-1\"/>\n    <code value=\"nl-NL\"/>\n    <display value=\"Dutch\"/>\n</coding>\n</communication>\n<managingOrganization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</managingOrganization>\n    <active value=\"true\"/>\n</Patient>\n"}", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Patient/f201"})

    stub_request(:post, "#{TESTING_ENDPOINT}/Organization").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Organization\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"Zorginstelling naam\"/>\n    <system value=\"http://www.zorgkaartnederland.nl/\"/>\n    <value value=\"Artis University Medical Center\"/>\n</identifier>\n    <name value=\"Artis University Medical Center (AUMC)\"/>\n<type\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"405608006\"/>\n    <display value=\"Academic Medical Center\"/>\n</coding>\n<coding\n>\n    <system value=\"urn:oid:2.16.840.1.113883.2.4.15.1060\"/>\n    <code value=\"V6\"/>\n    <display value=\"University Medical Hospital\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/organization-type\"/>\n    <code value=\"prov\"/>\n    <display value=\"Healthcare Provider\"/>\n</coding>\n</type>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31715269111\"/>\n    <use value=\"work\"/>\n</telecom>\n<address\n>\n    <use value=\"work\"/>\n    <line value=\"Walvisbaai 3\"/>\n    <city value=\"Den Helder\"/>\n    <postalCode value=\"2333ZA\"/>\n    <country value=\"NLD\"/>\n</address>\n    <contact\n>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Professor Brand\"/>\n    <family value=\"Brand\"/>\n    <given value=\"Ronald\"/>\n    <prefix value=\"Prof.Dr.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31715269702\"/>\n    <use value=\"work\"/>\n</telecom>\n<address\n>\n    <line value=\"Walvisbaai 3\"/><line value=\"Gebouw 2\"/>\n    <city value=\"Den helder\"/>\n    <postalCode value=\"2333ZA\"/>\n    <country value=\"NLD\"/>\n</address>\n</contact>\n    <active value=\"true\"/>\n</Organization>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1624',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Organization', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Organization/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Organization/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Organization', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Organization").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Organization\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f203\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"Zorginstelling naam\"/>\n    <system value=\"http://www.zorgkaartnederland.nl/\"/>\n    <value value=\"Blijdorp MC\"/>\n</identifier>\n    <name value=\"Blijdorp Medisch Centrum (BUMC)\"/>\n<type\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"405608006\"/>\n    <display value=\"Academic Medical Center\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/organization-type\"/>\n    <code value=\"prov\"/>\n</coding>\n</type>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31107040704\"/>\n    <use value=\"work\"/>\n</telecom>\n<address\n>\n    <use value=\"work\"/>\n    <line value=\"apenrots 230\"/>\n    <city value=\"Blijdorp\"/>\n    <postalCode value=\"3056BE\"/>\n    <country value=\"NLD\"/>\n</address>\n    <active value=\"true\"/>\n</Organization>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'927',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Organization', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Organization/f203"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Organization/f203").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f203', 'Resource'=>'FHIR::Organization', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Practitioner").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Practitioner\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"official\"/>\n    <label value=\"UZI-nummer\"/>\n    <system value=\"urn:oid:2.16.528.1.1007.3.1\"/>\n    <value value=\"12345678901\"/>\n</identifier>\n<name\n>\n    <use value=\"official\"/>\n    <text value=\"Dokter Bronsig\"/>\n    <family value=\"Bronsig\"/>\n    <given value=\"Arend\"/>\n    <prefix value=\"Dr.\"/>\n</name>\n<telecom\n>\n    <system value=\"phone\"/>\n    <value value=\"+31715269111\"/>\n    <use value=\"work\"/>\n</telecom>\n<address\n>\n    <use value=\"work\"/>\n    <line value=\"Walvisbaai 3\"/><line value=\"C4 - Automatisering\"/>\n    <city value=\"Den helder\"/>\n    <postalCode value=\"2333ZA\"/>\n    <country value=\"NLD\"/>\n</address>\n    <gender value=\"male\"/>\n    <birthDate value=\"1956-12-24\"/>\n<organization\n>\n    <reference value=\"Organization/f201\"/>\n    <display value=\"AUMC\"/>\n</organization>\n<role\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"225304007\"/>\n    <display value=\"Implementation of planned interventions\"/>\n</coding>\n</role>\n<specialty\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"310512001\"/>\n    <display value=\"Medical oncologist\"/>\n</coding>\n</specialty>\n    <qualification\n>\n<code\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"41672002\"/>\n    <display value=\"Pulmonologist\"/>\n</coding>\n</code>\n</qualification>\n</Practitioner>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1457',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Practitioner', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Practitioner/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Practitioner/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Practitioner', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Condition").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Condition\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f205\"/>\n<subject\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</subject>\n<asserter\n>\n    <reference value=\"Practitioner/f201\"/>\n</asserter>\n    <dateAsserted value=\"2013-04-04\"/>\n<code\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"87628006\"/>\n    <display value=\"Bacterial infectious disease\"/>\n</coding>\n</code>\n    <status value=\"working\"/>\n</Condition>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'503',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Condition', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Condition/f205"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Condition/f205").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f205', 'Resource'=>'FHIR::Condition', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Observation").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Observation\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f202\"/>\n<name\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"415945006\"/>\n    <display value=\"Oral temperature\"/>\n</coding>\n<coding\n>\n    <system value=\"http://loinc.org\"/>\n    <code value=\"8310-5\"/>\n    <display value=\"Body temperature\"/>\n</coding>\n    <text value=\"Body temperature\"/>\n</name>\n<valueQuantity\n>\n    <value value=\"39.0\"/>\n    <units value=\"degrees C\"/>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"258710007\"/>\n</valueQuantity>\n<interpretation\n>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v2/0078\"/>\n    <code value=\"H\"/>\n</coding>\n</interpretation>\n    <issued value=\"2013-04-04T12:27:00Z\"/>\n    <status value=\"entered in error\"/>\n    <reliability value=\"questionable\"/>\n<bodySite\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"38266002\"/>\n    <display value=\"Entire body as a whole\"/>\n</coding>\n</bodySite>\n<method\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"89003005\"/>\n    <display value=\"Oral temperature taking\"/>\n</coding>\n</method>\n<subject\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</subject>\n<performer\n>\n    <reference value=\"Practitioner/f201\"/>\n</performer>\n    <referenceRange\n>\n<low\n>\n    <value value=\"37.5\"/>\n    <units value=\"degrees C\"/>\n</low>\n</referenceRange>\n</Observation>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1444',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Observation', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Observation/f202"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Observation/f202").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f202', 'Resource'=>'FHIR::Observation', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/DiagnosticReport").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DiagnosticReport\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<name\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"429858000\"/>\n    <display value=\"Computed tomography (CT) of head and neck\"/>\n</coding>\n    <text value=\"CT of head-neck\"/>\n</name>\n    <status value=\"final\"/>\n    <issued value=\"2012-12-01T12:00:00+01:00\"/>\n<subject\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</subject>\n<performer\n>\n    <reference value=\"Organization/f203\"/>\n    <display value=\"Blijdorp MC\"/>\n</performer>\n<serviceCategory\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"394914008\"/>\n    <display value=\"Radiology\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/v2/0074\"/>\n    <code value=\"RAD\"/>\n</coding>\n</serviceCategory>\n    <diagnosticDateTime value=\"2012-12-01T12:00:00+01:00\"/>\n    <conclusion value=\"CT brains: large tumor sphenoid/clivus.\"/>\n<codedDiagnosis\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"188340000\"/>\n    <display value=\"Malignant tumor of craniopharyngeal duct\"/>\n</coding>\n</codedDiagnosis>\n</DiagnosticReport>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1192',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::DiagnosticReport', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/DiagnosticReport/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/DiagnosticReport/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::DiagnosticReport', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Encounter").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Encounter\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<identifier\n>\n    <use value=\"temp\"/>\n    <label value=\"Roel's encounter on April fourth 2013\"/>\n    <value value=\"Encounter_Roel_20130404\"/>\n</identifier>\n    <status value=\"finished\"/>\n    <class value=\"outpatient\"/>\n<type\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"11429006\"/>\n    <display value=\"Consultation\"/>\n</coding>\n</type>\n<patient\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</patient>\n    <participant\n>\n<individual\n>\n    <reference value=\"Practitioner/f201\"/>\n</individual>\n</participant>\n<reason\n>\n    <text value=\"The patient had fever peaks over the last couple of days. He is worried about these peaks.\"/>\n</reason>\n<priority\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"17621005\"/>\n    <display value=\"Normal\"/>\n</coding>\n</priority>\n<serviceProvider\n>\n    <reference value=\"Organization/f201\"/>\n</serviceProvider>\n</Encounter>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1035',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Encounter', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Encounter/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Encounter/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Encounter', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Encounter").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Encounter\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f202\"/>\n<identifier\n>\n    <use value=\"temp\"/>\n    <label value=\"Roel's encounter on January 28th, 2013\"/>\n    <value value=\"Encounter_Roel_20130128\"/>\n</identifier>\n    <status value=\"finished\"/>\n    <class value=\"outpatient\"/>\n<type\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"367336001\"/>\n    <display value=\"Chemotherapy\"/>\n</coding>\n</type>\n<patient\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</patient>\n    <participant\n>\n<individual\n>\n    <reference value=\"Practitioner/f201\"/>\n</individual>\n</participant>\n<length\n>\n    <value value=\"56.0\"/>\n    <units value=\"minutes\"/>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"258701004\"/>\n</length>\n<reason\n>\n    <text value=\"The patient is treated for a tumor.\"/>\n</reason>\n<indication\n>\n    <reference value=\"Procedure/f201\"/>\n    <display value=\"Roel's TPF chemotherapy on January 28th, 2013\"/>\n</indication>\n<priority\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"103391001\"/>\n    <display value=\"Urgent\"/>\n</coding>\n</priority>\n<serviceProvider\n>\n    <reference value=\"Organization/f201\"/>\n</serviceProvider>\n</Encounter>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1270',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Encounter', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Encounter/f202"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Encounter/f202").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f202', 'Resource'=>'FHIR::Encounter', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Procedure").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Procedure\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<patient\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</patient>\n<type\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"367336001\"/>\n    <display value=\"Chemotherapy\"/>\n</coding>\n</type>\n<bodySite\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"272676008\"/>\n    <display value=\"Sphenoid bone\"/>\n</coding>\n</bodySite>\n<indication\n>\n    <text value=\"DiagnosticReport/f201\"/>\n</indication>\n    <performer\n>\n<person\n>\n    <reference value=\"Practitioner/f201\"/>\n    <display value=\"Dokter Bronsig\"/>\n</person>\n<role\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"310512001\"/>\n    <display value=\"Medical oncologist\"/>\n</coding>\n</role>\n</performer>\n<date\n>\n    <start value=\"2013-01-28T13:31:00+01:00\"/>\n    <end value=\"2013-01-28T14:27:00+01:00\"/>\n</date>\n<encounter\n>\n    <reference value=\"Encounter/f202\"/>\n    <display value=\"Roel's encounter on January 28th, 2013\"/>\n</encounter>\n    <notes value=\"Eerste neo-adjuvante TPF-kuur bij groot proces in sphenoid met intracraniale uitbreiding.\"/>\n</Procedure>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1209',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Procedure', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Procedure/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Procedure/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Procedure', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    stub_request(:post, "#{TESTING_ENDPOINT}/Condition").
      with(:body => "#{"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Condition\n xmlns=\"http://hl7.org/fhir\">\n    \t<id value=\"f201\"/>\n<subject\n>\n    <reference value=\"Patient/f201\"/>\n    <display value=\"Roel\"/>\n</subject>\n<encounter\n>\n    <reference value=\"Encounter/f201\"/>\n</encounter>\n<asserter\n>\n    <reference value=\"Practitioner/f201\"/>\n</asserter>\n    <dateAsserted value=\"2013-04-04\"/>\n<code\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"386661006\"/>\n    <display value=\"Fever\"/>\n</coding>\n</code>\n<category\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"55607006\"/>\n    <display value=\"Problem\"/>\n</coding>\n<coding\n>\n    <system value=\"http://hl7.org/fhir/condition-category\"/>\n    <code value=\"condition\"/>\n</coding>\n</category>\n    <status value=\"confirmed\"/>\n<severity\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"255604002\"/>\n    <display value=\"Mild\"/>\n</coding>\n</severity>\n    <onsetDateTime value=\"2013-04-02\"/>\n    <evidence\n>\n<code\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"258710007\"/>\n    <display value=\"degrees C\"/>\n</coding>\n</code>\n<detail\n>\n    <reference value=\"Observation/f202\"/>\n    <display value=\"Temperature\"/>\n</detail>\n</evidence>\n    <location\n>\n<code\n>\n<coding\n>\n    <system value=\"http://snomed.info/sct\"/>\n    <code value=\"38266002\"/>\n    <display value=\"Entire body as a whole\"/>\n</coding>\n</code>\n</location>\n    <dueTo\n>\n<target\n>\n    <reference value=\"Procedure/f201\"/>\n    <display value=\"TPF chemokuur\"/>\n</target>\n</dueTo>\n<dueTo\n>\n<target\n>\n    <reference value=\"Condition/f205\"/>\n    <display value=\"bacterial infection\"/>\n</target>\n</dueTo>\n</Condition>\n"}",
        :headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'1689',
        'Content-Type'=>'application/xml+fhir;charset=UTF-8', 'Format'=>'',
        'Id'=>'', 'Resource'=>'FHIR::Condition', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {'Content-Location' => "#{TESTING_ENDPOINT}/Condition/f201"})

    stub_request(:delete, "#{TESTING_ENDPOINT}/Condition/f201").
      with(:headers => {'Accept'=>'application/xml+fhir', 'Accept-Charset'=>'UTF-8',
        'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/xml+fhir;charset=UTF-8',
        'Format'=>'', 'Id'=>'f201', 'Resource'=>'FHIR::Condition', 'User-Agent'=>'Ruby FHIR Client for FHIR'}).
        to_return(:status => 200, :body => "", :headers => {})

    client = FHIR::Client.new(TESTING_ENDPOINT)

    # only execute the methods that have stubs; remaining methods require complicated stubs
    trackTwoTest = Crucible::Tests::TrackTwoTest.new(client)
    results = trackTwoTest.execute_test_methods(trackTwoTest.tests(['C8T2_1A', 'C8T2_1B', 'C8T2_2A', 'C8T2_2B', 'C8T2_2C']))

    assert !results.blank?, 'Failed to execute TrackTwoTest.'
  end

end
