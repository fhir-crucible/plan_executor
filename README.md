# Plan Executor [![Build Status](https://travis-ci.org/fhir-crucible/plan_executor.svg?branch=master)](https://travis-ci.org/fhir-crucible/plan_executor)

Plan Executor runs test suites against a FHIR server.

# STU3

Updated to support the FHIR [STU3 Candidate branch](http://hl7.org/fhir/2016May/index.html).

## Getting Started

```
$ bundle install
$ bundle exec rake -T
```

## Listing Test Suites

List all the available Test Suites, excluding supported `TestScripts`. Pass the version, which can currently either be `dstu2` or `stu3`.

```
$ bundle exec rake crucible:list_suites[dstu2]
```

## Executing a Test Suite

Crucible tests can be executed by suite from the command-line by calling the `crucible-execute` rake task with the following parameters:

* `url` the FHIR endpoint
* `version` the FHIR version (sequence).  Currently `dstu2` and `stu3` are supported.
* `test` the name of the test suite (see `crucible:list_suites`)
* `resource` (optional) limit the `test` (applicable to "ResourceTest" or "SearchTest" suites) to a given resource (e.g. "Patient")

Run a DSTU2 Suite
```
$ bundle exec rake crucible:execute[http://fhirtest.uhn.ca/baseDstu2,dstu2,TransactionAndBatchTest]
```

Run a STU3 Suite limited by Resource
```
$ bundle exec rake crucible:execute[http://fhirtest.uhn.ca/baseDstu3,stu3,ResourceTest,Patient]
```

## Adding a New Test Suite

1. Fork the repo
2. Write the test suite in Ruby
3. Issue a pull request

Add a Test Suite by adding a Ruby file to `lib/tests/suites` that extends `Crucible::Tests::BaseTest` -- for example, `FooTest`:

```ruby
module Crucible
  module Tests
    class FooTest < BaseSuite

      def id
        'FooTest'
      end

      def description
        'FooTest is an example of adding a new test suite.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        # create any fixtures you need here
        @patient = ResourceGenerator.generate(FHIR::Patient,3)
        reply = @client.create(@patient)
        @id = reply.id
        @body = reply.body
      end

      def teardown
        # perform any clean up here
        @client.destroy(FHIR::Patient, @id)
      end

      # test 'KEY', 'DESCRIPTION'
      test 'FOO', 'Foo Test checks headers' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read"]
          validates resource: "Patient", methods: ["read"]
        }

        assert(@id, 'Setup was unable to create a patient.',@body)
        reply = @client.read(FHIR::Patient, @id)
        assert_response_ok(reply)
        assert_equal @id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end
    end
  end
end
```

Every Test Suite needs to override the following methods:
* `id` The unique id of the test, typically matches the class name
* `description` The description that is displayed within the Crucible web app
* `initialize` Use the example above. Change the `@category` -- the `id` and `title`
determine where the test suite is categorized within the Crucible web app
* `setup` (optional) Use this method to create fixtures and perform any required
assertions prior to execution of individual `test` blocks.
* `test` These blocks are the individual tests within the suites. Each block should start with a `metadata` section so Crucible knows how to tie the success or failures to portions of the FHIR specification (displayed in the web app with a starburst). See `lib/FHIR_structure.json` for the values associated with the `name` keys that you can link to.
* `teardown` (optional) Use this method to perform any clean up, so you don't leave
a trail of test data behind.

# License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
