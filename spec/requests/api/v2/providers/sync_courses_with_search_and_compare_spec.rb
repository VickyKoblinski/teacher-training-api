describe "Courses API v2", type: :request do
  let(:user)         { create(:user) }
  let(:organisation) { create(:organisation, users: [user]) }
  let(:payload)      { { email: user.email } }
  let(:token)        { build_jwt :apiv2, payload: payload }
  let(:credentials) do
    ActionController::HttpAuthentication::Token.encode_credentials(token)
  end
  let(:site) { build(:site) }
  let(:dfe_subject) { find_or_create(:primary_subject, :primary_with_mathematics) }
  let(:non_dfe_subject) { find_or_create(:secondary_subject, :modern_languages) }
  let(:findable_site_status_1) { build(:site_status, :findable, site: site) }
  let(:findable_site_status_2) { build(:site_status, :findable, site: site) }
  let(:suspended_site_status) { build(:site_status, :suspended, site: site) }
  let(:syncable_course) { create(:course, :infer_level, site_statuses: [findable_site_status_1], subjects: [dfe_subject]) }
  let(:suspended_course) { create(:course, :infer_level, site_statuses: [suspended_site_status], subjects: [dfe_subject]) }
  let(:invalid_subject_course) { create(:course, :infer_level, site_statuses: [findable_site_status_2], subjects: [non_dfe_subject]) }
  let(:provider) do
    create(:provider,
           organisations: [organisation],
             courses: [syncable_course, suspended_course, invalid_subject_course],
             sites: [site])
  end

  describe "POST " do
    let(:status) { 200 }
    let(:stubbed_request_body) { WebMock::Matchers::AnyArgMatcher.new(nil) }
    let(:stubbed_request) do
      stub_request(:put, "#{MCBE.search_api.base_url}/api/courses/")
        .with(body: stubbed_request_body)
        .to_return(
          status: status,
        )
    end

    before do
      stubbed_request
    end

    subject do
      post sync_path, headers: { "HTTP_AUTHORIZATION" => credentials }
      response
    end

    let(:sync_path) do
      "/api/v2/providers/#{provider.provider_code}/sync_courses_with_search_and_compare"
    end

    context "when unauthenticated" do
      let(:payload) { { email: "foo@bar" } }

      it { should have_http_status(:unauthorized) }
    end

    context "when user has not accepted terms" do
      let(:user)         { create(:user, accept_terms_date_utc: nil) }
      let(:organisation) { create(:organisation, users: [user]) }

      it { should have_http_status(:forbidden) }
    end

    context "when unauthorised" do
      let(:unauthorised_user) { create(:user) }
      let(:payload)           { { email: unauthorised_user.email } }

      it "raises an error" do
        expect { subject }.to raise_error Pundit::NotAuthorizedError
      end
    end

    context "when authorized" do
      context "current recruitment cycle " do
        let(:sync_path) do
          "/api/v2/recruitment_cycles/#{provider.recruitment_cycle.year}" +
            "/providers/#{provider.provider_code}/sync_courses_with_search_and_compare"
        end

        context "when a successful external call to search has been made" do
          let(:stubbed_request_body) { include("\"ProviderCode\":\"#{provider.provider_code}\"", "\"ProgrammeCode\":\"#{syncable_course.course_code}\"") }

          it "should be successful" do
            expect(subject).to have_http_status(:ok)
          end

          it "should make the appropriate request" do
            perform_enqueued_jobs do
              subject
            end

            expect(WebMock)
              .to have_requested(:put, "#{MCBE.search_api.base_url}/api/courses/")
          end
        end
      end

      context "next recruitment cycle" do
        let(:sync_path) do
          "/api/v2/recruitment_cycles/#{provider.recruitment_cycle.year}" +
            "/providers/#{provider.provider_code}/sync_courses_with_search_and_compare"
        end
        let(:next_cycle) { build(:recruitment_cycle, :next) }
        let(:syncable_course) { build(:course, :infer_level, site_statuses: [findable_site_status_1], subjects: [dfe_subject]) }
        let(:provider) do
          create(:provider,
                 organisations: [organisation],
                         courses: [syncable_course],
                         sites: [site],
                         recruitment_cycle: next_cycle)
        end

        it "should throw an error" do
          expect { subject }.to raise_error("#{provider} is not from the current recruitment cycle")
        end
      end
    end
  end
end
