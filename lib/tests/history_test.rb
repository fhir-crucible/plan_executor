module Crucible
  module Tests
    class HistoryTest < BaseTest

      def id
        'History001'
      end

      def description
        'Initial Sprinkler tests (HI01,HI02,HI03,HI04,HI05,HI06,HI07,HI08,HI09,HI10,HI11) for testing resource history requests.'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient

        create_date = Time.now

        @version = []
        result = @client.create(@patient)
        @id = result.id
        @version << result.version

        @patient.telecom << FHIR::Contact.new(system: 'email', value: 'foo@example.com')

        update_result = @client.update(@patient, @id)
        @version << update_result.version

      end

      test 'HI01','History for specific resource' do
        setup

        result = @client.resource_instance_history(FHIR::Patient,@id)

        assert result.resource.size == @version.length, "failed test"

        # TestResult.new('HI01','History for specific resource','passed', 'message', 'response')
      end 

        # [SprinklerTest("HI01", "Request the full history for a specific resource")]
        # public void HistoryForSpecificResource()
        # {
        #     Initialize();
        #     if (_createDate == null) TestResult.Skip();

        #     _history = Client.History(_location);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(_history);

        #     // There's one version less here, because we don't have the deletion
        #     int expected = Versions.Count + 1;

        #     if (_history.Entries.Count != expected)
        #         Assert.Fail(String.Format("{0} versions expected after crud test, found {1}", expected,
        #             _history.Entries.Count));

        #     if (!_history.Entries.OfType<ResourceEntry>()
        #         .All(ent => Versions.Contains(ent.SelfLink)))
        #         Assert.Fail("Selflinks on returned versions do not match links returned on creation" +
        #                         _history.Entries.Count);


        #     CheckSortOrder(_history);
        # }


        test "HI02", "full history with since" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI02", "Request the full history for a resource with _since")]
        # public void HistoryForSpecificResourceId()
        # {
        #     if (_createDate == null) TestResult.Skip();

        #     DateTimeOffset before = _createDate.Value.AddMinutes(-1);
        #     DateTimeOffset after = before.AddHours(1);

        #     Bundle history = Client.History(_location, before);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(history);
        #     CheckSortOrder(history);
        #     Uri[] historySl = history.Entries.Select(entry => entry.SelfLink).ToArray();

        #     if (!history.Entries.All(entry => historySl.Contains(entry.SelfLink)))
        #         Assert.Fail("history with _since does not contain all versions of instance");

        #     history = Client.History(_location, after);
        #     if (history.Entries.Count != 0)
        #         Assert.Fail("Setting since to after the last update still returns history");
        # }

        test "HI03", "individual history versions" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI03", "Request individual history versions from a resource")]
        # public void VReadVersions()
        # {
        #     foreach (ResourceEntry ent in _history.Entries.OfType<ResourceEntry>())
        #     {
        #         var identity = new ResourceIdentity(ent.SelfLink);

        #         ResourceEntry<Patient> version = Client.Read<Patient>(identity);

        #         if (version == null) Assert.Fail("Cannot find version that was present in history");

        #         Assert.ContentLocationPresentAndValid(Client);
        #         var selfLink = new ResourceIdentity(Client.LastResponseDetails.ContentLocation);
        #         if (String.IsNullOrEmpty(selfLink.Id) || String.IsNullOrEmpty(selfLink.VersionId))
        #             Assert.Fail("Optional Content-Location contains an invalid version-specific url");
        #     }

        #     foreach (DeletedEntry ent in _history.Entries.OfType<DeletedEntry>())
        #     {
        #         var identity = new ResourceIdentity(ent.SelfLink);

        #         Assert.Fails(Client, () => Client.Read<Patient>(identity), HttpStatusCode.Gone);
        #     }
        # }

        test "HI04", "history for missing resource" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI04", "Fetching history of non-existing resource returns exception")]
        # public void HistoryForNonExistingResource()
        # {
        #     if (_createDate == null) TestResult.Skip();

        #     Assert.Fails(Client, () => Client.History("Patient/3141592unlikely"), HttpStatusCode.NotFound);
        # }

        test "HI06", "all history for resource with since" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI06", "Get all history for a resource type with _since")]
        # public void HistoryForResourceType()
        # {
        #     if (_createDate == null) TestResult.Skip();

        #     DateTimeOffset before = _createDate.Value.AddMinutes(-1);
        #     DateTimeOffset after = before.AddHours(1);

        #     Bundle history = Client.TypeHistory<Patient>(before);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(history);
        #     _typeHistory = history;
        #     CheckSortOrder(history);

        #     Uri[] historyLinks = history.Entries.Select(be => be.SelfLink).ToArray();

        #     if (!history.Entries.All(ent => historyLinks.Contains(ent.SelfLink)))
        #         Assert.Fail("history with _since does not contain all versions of instance");

        #     history = Client.History(_location, DateTimeOffset.Now.AddMinutes(1));

        #     if (history.Entries.Count != 0)
        #         Assert.Fail("Setting since to a future moment still returns history");
        # }


        test "HI08", "all history whole system with since" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI08", "Get the history for the whole system with _since")]
        # public void HistoryForWholeSystem()
        # {
        #     if (_createDate == null) TestResult.Skip();
        #     DateTimeOffset before = _createDate.Value.AddMinutes(-1);
        #     Bundle history;


        #     history = Client.WholeSystemHistory(before);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(history);

        #     Assert.HasAllForwardNavigationLinks(history); // Assumption: system has more history than pagesize
        #     _systemHistory = history;
        #     CheckSortOrder(history);

        #     Uri[] historyLinks = history.Entries.Select(be => be.SelfLink).ToArray();

        #     if (!Versions.All(sl => historyLinks.Contains(sl)))
        #         Assert.Fail("history with _since does not contain all versions of instance");

        #     history = Client.History(_location, DateTimeOffset.Now.AddMinutes(1));

        #     if (history.Entries.Count != 0)
        #         Assert.Fail("Setting since to a future moment still returns history");
        # }

        test "HI09", "resource history page forward" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI09", "Paging forward through a resource type history")]
        # public void PageFwdThroughResourceHistory()
        # {
        #     int pageSize = 30;
        #     Bundle page = Client.TypeHistory<Patient>(since: DateTimeOffset.Now.AddHours(-1), pageSize: pageSize);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(page);

        #     _forwardCount = 0;

        #     // Browse forwards
        #     while (page != null)
        #     {
        #         if (page.Entries.Count > pageSize)
        #             Assert.Fail("Server returned a page with more entries than set by _count");

        #         _forwardCount += page.Entries.Count;
        #         _lastPage = page;
        #         Assert.EntryIdsArePresentAndAbsoluteUrls(page);
        #         page = Client.Continue(page);
        #     }

        #     //if (total.HasValue && forwardCount < total)
        #     //    TestResult.Fail(String.Format("Paging did not return all entries(expected at least {0}, {1} returned)", 
        #     //                    total, forwardCount));
        # }

        test "HI10", "resource history page backwards" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI10", "Page backwards through a resource type history")]
        # public void PageBackThroughResourceHistory()
        # {
        #     if (_forwardCount == -1) TestResult.Skip();

        #     int pageSize = 30;
        #     Bundle page = Client.TypeHistory<Patient>(since: DateTimeOffset.Now.AddHours(-1), pageSize: pageSize);
        #     Assert.EntryIdsArePresentAndAbsoluteUrls(page);

        #     page = Client.Continue(page, PageDirection.Last);
        #     int backwardsCount = 0;

        #     // Browse backwards
        #     while (page != null)
        #     {
        #         if (page.Entries.Count > pageSize)
        #             Assert.Fail("Server returned a page with more entries than set by count");

        #         backwardsCount += page.Entries.Count;
        #         Assert.EntryIdsArePresentAndAbsoluteUrls(page);
        #         page = Client.Continue(page, PageDirection.Previous);
        #     }

        #     if (backwardsCount != _forwardCount)
        #         Assert.Fail(String.Format("Paging forward returns {0} entries, backwards returned {1}",
        #             _forwardCount, backwardsCount));
        # }

        test "HI11", "first page full history" do
          raise 'Implementation missing...'
        end
        # [SprinklerTest("HI11", "Fetch first page of full histroy")]
        # public void FullHistory()
        # {
        #     Bundle history = Client.WholeSystemHistory();
        # }


        # private static void CheckSortOrder(Bundle bundle)
        # {
        #     DateTimeOffset maxDate = DateTimeOffset.MaxValue;

        #     foreach (BundleEntry be in bundle.Entries)
        #     {
        #         DateTimeOffset? lastUpdate = be is ResourceEntry
        #             ? ((be as ResourceEntry).LastUpdated)
        #             : ((be as DeletedEntry).When);

        #         if (lastUpdate == null)
        #             Assert.Fail(String.Format("Result contains entry with no LastUpdate (id: {0})", be.SelfLink));

        #         if (lastUpdate > maxDate)
        #             Assert.Fail("Result is not ordered on LastUpdate, first out of order has id " + be.SelfLink);

        #         maxDate = lastUpdate.Value;
        #     }
        # }



    end
  end
end