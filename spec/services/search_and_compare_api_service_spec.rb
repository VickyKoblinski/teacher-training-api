require "rails_helper"

describe SearchAndCompareAPIService do
  describe "Connection.api" do
    subject { described_class::Connection.api }

    it "exposes an Faraday connection" do
      should be_instance_of(Faraday::Connection)
    end

    it "uses the configured URL as the base" do
      expect(subject.url_prefix.to_s).to eq(MCBE.search_api.base_url + "/")
    end

    it "uses the configured secret for the bearer token" do
      expect(subject.headers["Authorization"]).to eq("Bearer #{MCBE.search_api.secret}")
    end

    it "uses the RequestStore for the request_id" do
      request_id = SecureRandom.uuid

      allow(RequestStore).to receive(:store).and_return(request_id: request_id)

      expect(subject.headers["X-Request-ID"]).to eq(request_id)
    end
  end

  describe "Request" do
    let(:request) { described_class::Request.new }
    let(:body) do
      ActiveModel::Serializer::CollectionSerializer.new(
        [course],
        serializer: SearchAndCompare::CourseSerializer,
        adapter: :attributes,
      )
    end

    let(:published_enrichment) do
      build :course_enrichment, :published,
            created_at: 5.days.ago
    end

    let(:course) { create :course, enrichments: [published_enrichment] }

    let(:course_code) { course.course_code }
    let(:provider_code) { course.provider.provider_code }

    let(:status) { 200 }
    let(:http_verb) { :put }

    before do
      stub_request(http_verb, "#{MCBE.search_api.base_url}/api/courses/")
        .with { |req| req.body == body.to_json }
        .to_return(
          status: status,
        )
    end

    describe "sync" do
      subject {
        request.sync(
          [course],
        )
      }
      describe "with a normal response" do
        it { should eq true }
      end

      describe "with a bad response" do
        let(:status) { 400 }
        it { should eq false }
      end
    end

    describe "bulk_sync" do
      let(:http_verb) { :post }

      subject {
        request.bulk_sync(
          [course],
        )
      }
      describe "with a normal response" do
        it { should eq true }
      end

      describe "with a bad response" do
        let(:status) { 400 }
        it { should eq false }
      end
    end
  end
end
