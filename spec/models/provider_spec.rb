# == Schema Information
#
# Table name: provider
#
#  id                   :integer          not null, primary key
#  address4             :text
#  provider_name        :text
#  scheme_member        :text
#  contact_name         :text
#  year_code            :text
#  provider_code        :text
#  provider_type        :text
#  postcode             :text
#  scitt                :text
#  url                  :text
#  address1             :text
#  address2             :text
#  address3             :text
#  email                :text
#  telephone            :text
#  region_code          :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  accrediting_provider :text
#  last_published_at    :datetime
#  changed_at           :datetime         not null
#  recruitment_cycle_id :integer          not null
#

require 'rails_helper'

describe Provider, type: :model do
  subject { create(:provider, provider_name: 'ACME SCITT', provider_code: 'A01') }

  its(:to_s) { should eq('ACME SCITT (A01)') }

  describe 'auditing' do
    it { should be_audited.except(:changed_at) }
    it { should have_associated_audits }
  end

  describe 'associations' do
    it { should have_many(:sites) }
    it { should have_many(:users).through(:organisations) }
    it { should have_one(:ucas_preferences).class_name('ProviderUCASPreference') }
    it { should have_many(:contacts) }
  end

  describe 'changed_at' do
    it 'is set on create' do
      provider = Provider.create(
        recruitment_cycle: find_or_create(:recruitment_cycle)
      )
      expect(provider.changed_at).to be_present
      expect(provider.changed_at).to eq provider.updated_at
    end

    it 'is set on update' do
      Timecop.freeze do
        provider = create(:provider, updated_at: 1.hour.ago)
        provider.touch
        expect(provider.changed_at).to eq provider.updated_at
        expect(provider.changed_at).to eq Time.now.utc
      end
    end
  end

  describe '#changed_since' do
    context 'with a provider that has been changed after the given timestamp' do
      let(:provider) { create(:provider, changed_at: 5.minutes.ago) }

      subject { Provider.changed_since(10.minutes.ago) }

      it { should include provider }
    end

    context 'with a provider that has been changed less than a second after the given timestamp' do
      let(:timestamp) { 5.minutes.ago }
      let(:provider) { create(:provider, changed_at: timestamp + 0.001.seconds) }

      subject { Provider.changed_since(timestamp) }

      it { should include provider }
    end

    context 'with a provider that has been changed exactly at the given timestamp' do
      let(:publish_time) { 10.minutes.ago }
      let(:provider) { create(:provider, changed_at: publish_time) }

      subject { Provider.changed_since(publish_time) }

      it { should_not include provider }
    end

    context 'with a provider that has been changed before the given timestamp' do
      let(:provider) { create(:provider, changed_at: 1.hour.ago) }

      subject { Provider.changed_since(10.minutes.ago) }

      it { should_not include provider }
    end
  end

  describe '#external_contact_info' do
    context 'provider has draft and multiple published enrichments' do
      it 'returns contact info from the provider enrichment' do
        published_enrichment = build(:provider_enrichment, :published,
                                     last_published_at: 5.days.ago)
        latest_published_enrichment = build(:provider_enrichment, :published,
                                            last_published_at: 1.day.ago)
        enrichment = build(:provider_enrichment)

        provider = create(:provider, enrichments: [published_enrichment,
                                                   latest_published_enrichment,
                                                   enrichment])

        expect(provider.external_contact_info).to(
          eq(
            'address1'    => latest_published_enrichment.address1,
            'address2'    => latest_published_enrichment.address2,
            'address3'    => latest_published_enrichment.address3,
            'address4'    => latest_published_enrichment.address4,
            'postcode'    => latest_published_enrichment.postcode,
            'region_code' => latest_published_enrichment.region_code,
            'telephone'   => latest_published_enrichment.telephone,
            'email'       => latest_published_enrichment.email,
            'website'     => latest_published_enrichment.website
          )
        )
      end
    end

    context 'provider has no published enrichments' do
      it 'returns the info from the provider record' do
        provider = create(:provider)
        expect(provider.external_contact_info).to(
          eq(
            'address1'    => provider.address1,
            'address2'    => provider.address2,
            'address3'    => provider.address3,
            'address4'    => provider.address4,
            'postcode'    => provider.postcode,
            'region_code' => provider.region_code,
            'telephone'   => provider.telephone,
            'email'       => provider.email,
            'website'     => provider.url
          )
        )
      end
    end
  end

  describe '.in_order' do
    let!(:second_alphabetical_provider) { create(:provider, provider_name: "Zork") }
    let!(:first_alphabetical_provider) { create(:provider, provider_name: "Acme") }

    it 'returns sorted providers' do
      expect(Provider.in_order).to match_array([first_alphabetical_provider, second_alphabetical_provider])
    end
  end

  describe '#update_changed_at' do
    let(:provider) { create(:provider, changed_at: 1.hour.ago) }

    it 'sets changed_at to the current time' do
      Timecop.freeze do
        provider.update_changed_at
        expect(provider.changed_at).to eq Time.now.utc
      end
    end

    it 'sets changed_at to the given time' do
      timestamp = 1.hour.ago
      provider.update_changed_at timestamp: timestamp
      expect(provider.changed_at).to eq timestamp
    end

    it 'leaves updated_at unchanged' do
      timestamp = 1.hour.ago
      provider.update updated_at: timestamp

      provider.update_changed_at
      expect(provider.updated_at).to eq timestamp
    end
  end

  its(:recruitment_cycle) { should eq find(:recruitment_cycle) }

  describe '#unassigned_site_codes' do
    subject { create(:provider) }
    before do
      %w[A B C D 1 2 3 -].each { |code| subject.sites << build(:site, code: code) }
    end

    let(:expected_unassigned_codes) { ('E'..'Z').to_a + %w[0] + ('4'..'9').to_a }

    its(:unassigned_site_codes) { should eq(expected_unassigned_codes) }
  end

  describe "#can_add_more_sites?" do
    context "when provider has less sites than max allowed" do
      subject { create(:provider) }
      its(:can_add_more_sites?) { should be_truthy }
    end

    context "when provider has the max sites allowed" do
      let(:all_site_codes) { ('A'..'Z').to_a + %w[0 -] + ('1'..'9').to_a }
      let(:sites) do
        all_site_codes.map { |code| build(:site, code: code) }
      end

      subject { create(:provider, sites: sites) }

      its(:can_add_more_sites?) { should be_falsey }
    end
  end

  it 'defines an enum for accrediting_provider' do
    expect(subject)
      .to define_enum_for("accrediting_provider")
            .backed_by_column_of_type(:text)
            .with_values('accredited_body' => 'Y', 'not_an_accredited_body' => 'N')
  end

  describe "courses" do
    let!(:provider) { create(:provider) }
    let!(:course) { create(:course, provider: provider) }

    describe "#courses_count" do
      it 'returns course count using courses.size' do
        allow(provider.courses).to receive(:size).and_return(1)

        expect(provider.courses_count).to eq(1)
        expect(provider.courses).to have_received(:size)
      end

      context "with .include_courses_counts" do
        let(:provider_with_included) { Provider.include_courses_counts.first }

        it "return course count using included_courses_count" do
          allow(provider_with_included).to receive(:included_courses_count).and_return(1)
          allow(provider_with_included.courses).to receive(:size)

          expect(provider_with_included.courses_count).to eq(1)
          expect(provider_with_included).to have_received(:included_courses_count)
          expect(provider_with_included.courses).to_not have_received(:size)
        end
      end
    end

    describe ".include_courses_counts" do
      let(:first_provider) { Provider.include_courses_counts.first }

      it 'includes course counts' do
        expect(first_provider.courses_count).to eq(1)
      end
    end
  end
end
