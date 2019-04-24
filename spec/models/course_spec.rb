# == Schema Information
#
# Table name: course
#
#  id                      :integer          not null, primary key
#  age_range               :text
#  course_code             :text
#  name                    :text
#  profpost_flag           :text
#  program_type            :text
#  qualification           :integer          not null
#  start_date              :datetime
#  study_mode              :text
#  accrediting_provider_id :integer
#  provider_id             :integer          default(0), not null
#  modular                 :text
#  english                 :integer
#  maths                   :integer
#  science                 :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  changed_at              :datetime         not null
#

require 'rails_helper'

RSpec.describe Course, type: :model do
  let(:subject) { create(:course) }

  describe 'auditing' do
    it { should be_audited.except(:changed_at) }
    it { should have_associated_audits }
  end

  describe 'associations' do
    it { should belong_to(:provider) }
    it { should belong_to(:accrediting_provider).optional }
    it { should have_and_belong_to_many(:subjects) }
    it { should have_many(:site_statuses) }
    it { should have_many(:sites) }
  end

  describe 'changed_at' do
    it 'is set on create' do
      course = create(:course)
      expect(course.changed_at).to be_present
      expect(course.changed_at).to eq course.updated_at
    end

    it 'is set on update' do
      Timecop.freeze do
        course = create(:course, changed_at: 1.hour.ago)
        course.touch
        expect(course.changed_at).to eq course.updated_at
        expect(course.changed_at).to eq Time.now.utc
      end
    end
  end

  describe 'no site statuses' do
    its(:site_statuses) { should be_empty }
    its(:findable?) { should be false }
    its(:open_for_applications?) { should be false }
    its(:has_vacancies?) { should be false }
  end

  context 'with site statuses' do
    describe 'findable?' do
      context 'with at least one site status as findable' do
        context 'single site status as findable' do
          let(:subject) { create(:course, site_statuses: course_site_statuses) }

          let(:course_site_statuses) { [create(:site_status, :findable)] }

          its(:site_statuses) { should_not be_empty }
          its(:findable?) { should be true }
        end

        context 'single site status as findable and mix site status as non findable' do
          let(:subject) {
            create(:course, with_site_statuses: [
              [:findable],
              [:with_any_vacancy],
              [:default],
              [:applications_being_accepted_now],
              [:applications_being_accepted_in_future]
            ])
          }

          its(:site_statuses) { should_not be_empty }
          its(:findable?) { should be true }
        end
      end
    end

    describe '#has_vacancies?' do
      context 'for a single site status that has vacancies' do
        let(:subject) {
          create(:course, with_site_statuses: [%i[findable applications_being_accepted_now with_any_vacancy]])
        }

        its(:has_vacancies?) { should be true }
      end

      context 'for a site status with vacancies and others without' do
        let(:subject) {
          create(:course, with_site_statuses: [
            %i[findable applications_being_accepted_now with_any_vacancy],
            %i[findable with_no_vacancies],
            %i[findable with_no_vacancies],
          ])
        }

        its(:has_vacancies?) { should be true }
      end

      context 'when none of the sites have vacancies' do
        let(:subject) {
          create(:course, with_site_statuses: [
            %i[findable with_no_vacancies],
            %i[findable with_no_vacancies],
          ])
        }

        its(:has_vacancies?) { should be false }
      end

      context 'when the site is findable but only opens in the future' do
        let(:subject) {
          create(:course, with_site_statuses: [
            %i[findable with_any_vacancy applications_being_accepted_in_future],
          ])
        }

        its(:has_vacancies?) { should be true }
      end

      context 'when only discontinued and suspended site statuses have vacancies' do
        let(:subject) {
          create(:course, with_site_statuses: [
            %i[published suspended with_any_vacancy],
            %i[published discontinued with_any_vacancy],
            %i[findable with_no_vacancies],
          ])
        }

        its(:has_vacancies?) { should be false }
      end
    end

    describe 'open_for_applications?' do
      context 'with at least one site status applications_being_accepted_now' do
        context 'single site status applications_being_accepted_now as it open now' do
          let(:subject) {
            create(:course, with_site_statuses: [%i[findable applications_being_accepted_now with_any_vacancy]])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be true }
        end

        context 'single site status applications_being_accepted_now as it open future' do
          let(:subject) {
            create(:course, with_site_statuses: [:applications_being_accepted_in_future])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be false }
        end

        context 'site statuses applications_being_accepted_now as it open now & future' do
          let(:subject) {
            create(:course, with_site_statuses: [
              %i[findable applications_being_accepted_now with_any_vacancy],
              %i[applications_being_accepted_in_future with_any_vacancy]
            ])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be true }
        end

        context 'site statuses applications_being_accepted_now as it open now & future and mix site status as non findable' do
          let(:subject) {
            create(:course, with_site_statuses: [
              [:findable],
              [:with_any_vacancy],
              [:default],
              [:applications_being_accepted_now],
              [:applications_being_accepted_in_future]
            ])
          }

          its(:site_statuses) { should_not be_empty }
          its(:findable?) { should be true }
          its(:open_for_applications?) { should be false }
        end
      end
    end

    describe 'ucas_status' do
      context 'with a running site_status' do
        let(:subject) { create(:course, with_site_statuses: [%i[findable]]) }

        its(:ucas_status) { should eq :running }
      end

      context 'with a new site_status' do
        let(:subject) { create(:course, with_site_statuses: [%i[new]]) }

        its(:ucas_status) { should eq :new }
      end

      context 'with a not running site_status' do
        let(:subject) { create(:course, with_site_statuses: [%i[suspended]]) }

        its(:ucas_status) { should eq :not_running }
      end
    end

    its(:site_statuses) { should be_empty }
    its(:findable?) { should be false }
    its(:open_for_applications?) { should be false }
    its(:has_vacancies?) { should be false }
  end

  describe '#changed_since' do
    context 'with no parameters' do
      let!(:old_course) { create(:course, age: 1.hour.ago) }
      let!(:course) { create(:course, age: 1.hour.ago) }

      subject { Course.changed_since(nil) }

      it { should include course }
      it { should include old_course }
    end

    context 'with a course that was just updated' do
      let(:course) { create(:course, age: 1.hour.ago) }
      let!(:old_course) { create(:course, age: 1.hour.ago) }

      before { course.touch }

      subject { Course.changed_since(10.minutes.ago) }

      it { should include course }
      it { should_not include old_course }
    end

    context 'with a course that has been changed less than a second after the given timestamp' do
      let(:timestamp) { 5.minutes.ago }
      let(:course) { create(:course, changed_at: timestamp + 0.001.seconds) }

      subject { Course.changed_since(timestamp) }

      it { should include course }
    end

    context 'with a course that has been changed exactly at the given timestamp' do
      let(:timestamp) { 10.minutes.ago }
      let(:course) { create(:course, changed_at: timestamp) }

      subject { Course.changed_since(timestamp) }

      it { should_not include course }
    end
  end

  describe "#study_mode_description" do
    specs = {
      full_time: 'full time',
      part_time: 'part time',
      full_time_or_part_time: 'full time or part time',
    }.freeze

    specs.each do |study_mode, expected_description|
      context study_mode.to_s do
        subject { create(:course, study_mode: study_mode) }
        its(:study_mode_description) { should eq(expected_description) }
      end
    end
  end

  describe "#description" do
    context "for a both full time and part time course" do
      subject {
        create(:course,
               study_mode: :full_time_or_part_time,
               program_type: :scitt_programme,
               qualification: :qts)
      }

      its(:description) { should eq("QTS, full time or part time") }
    end

    specs = {
      "QTS, full time or part time" => {
        study_mode: :full_time_or_part_time,
        program_type: :scitt_programme,
        qualification: :qts,
      },
      "PGCE with QTS full time with salary" => {
        study_mode: :full_time,
        program_type: :school_direct_salaried_training_programme,
        qualification: :pgce_with_qts,
      }
    }.freeze

    specs.each do |expected_description, course_attributes|
      context "for #{expected_description} course" do
        subject { create(:course, course_attributes) }
        its(:description) { should eq(expected_description) }
      end
    end

    context "for a salaried course" do
      subject {
        create(:course,
               study_mode: :full_time,
               program_type: :school_direct_salaried_training_programme,
               qualification: :pgce_with_qts)
      }

      its(:description) { should eq("PGCE with QTS full time with salary") }
    end

    context "for a teaching apprenticeship" do
      subject {
        create(:course,
               study_mode: :part_time,
               program_type: :pg_teaching_apprenticeship,
               qualification: :pgde_with_qts)
      }

      its(:description) { should eq("PGDE with QTS part time teaching apprenticeship") }
    end
  end

  describe 'qualifications' do
    context "course with qts qualication" do
      let(:subject) { create(:course, :resulting_in_qts) }

      its(:qualifications) { should eq %i[qts] }
    end

    context "course with pgce qts qualication" do
      let(:subject) { create(:course, :resulting_in_pgce_with_qts) }

      its(:qualifications) { should eq %i[qts pgce] }
    end

    context "course with pgde qts qualication" do
      let(:subject) { create(:course, :resulting_in_pgde_with_qts) }

      its(:qualifications) { should eq %i[qts pgde] }
    end

    context "course with pgce qualication" do
      let(:subject) { create(:course, :resulting_in_pgce) }

      its(:qualifications) { should eq %i[pgce] }
    end

    context "course with pgde qualication" do
      let(:subject) { create(:course, :resulting_in_pgde) }

      its(:qualifications) { should eq %i[pgde] }
    end
  end

  describe '.providers_have_opted_in' do
    let(:course) { create(:course, provider: provider) }

    subject { Course.providers_have_opted_in }

    context 'provider is opted in' do
      let(:provider) { create(:provider, opted_in: true) }

      it { should include(course) }
    end

    context 'provider is not opted in' do
      let(:provider) { create(:provider, opted_in: false) }

      it { should_not include(course) }
    end
  end

  describe "#enrichments" do
    subject {
      create(:course, with_enrichments: [
        [:published, created_at: 5.days.ago],
        [:published, created_at: 3.days.ago],
        [:subsequent_draft, created_at: 1.day.ago],
      ]).enrichments
    }

    let(:another_course) {
      create(:course, with_enrichments: [
        [:published, created_at: 5.days.ago],
      ])
    }

    its(:size) { should eq(3) }

    it "doesn't overlap with enrichments from another course" do
      expect(subject & another_course.enrichments).to be_empty
    end
  end

  describe "#content_status" do
    context "for a course without any enrichments" do
      subject { create(:course, with_enrichments: []) }
      its(:content_status) { should eq(:empty) }
    end

    context "for a course an initial draft enrichments" do
      subject { create(:course, with_enrichments: [[:initial_draft]]) }
      its(:content_status) { should eq(:draft) }
    end

    context "for a course with a single published enrichment" do
      subject { create(:course, with_enrichments: [[:published]]) }
      its(:content_status) { should eq(:published) }
    end

    context "for a course with multiple published enrichments" do
      subject { create(:course, with_enrichments: [[:published], [:published]]) }
      its(:content_status) { should eq(:published) }
    end

    context "for a course with published enrichments and a draft one" do
      subject { create(:course, with_enrichments: [[:published], [:subsequent_draft]]) }
      its(:content_status) { should eq(:published_with_unpublished_changes) }
    end
  end

  describe "#publish_enrichments" do
    context 'on a course with only a draft enrichment' do
      let(:course) do
        create(:course,
            changed_at: 10.minutes.ago,
            with_enrichments: [[:initial_draft,
                                created_at: 1.day.ago,
                                updated_at: 20.minutes.ago]])
      end
      let(:user) { create(:user) }

      it 'publishes the draft' do
        course.publish_enrichment(user)
        expect(course.reload.enrichments.first).to be_published
      end

      it 'updates course changed_at to the current time' do
        course.publish_enrichment(user)
        expect(course.reload.changed_at).to be_within(1.second).of Time.now.utc
      end

      it 'updates enrichment updated_at to the current time' do
        course.publish_enrichment(user)
        expect(course.reload.enrichments.first.updated_at).to be_within(1.second).of Time.now.utc
      end

      it 'updates last_published to the current time' do
        course.publish_enrichment(user)
        expect(course.reload.enrichments.first.last_published_timestamp_utc).to be_within(1.second).of Time.now.utc
      end

      it 'updates updated_by to the current user' do
        course.publish_enrichment(user)
        expect(course.reload.enrichments.first.updated_by_user_id).to eq user.id
      end
    end

    context 'on a course with a draft enrichment and previously-published enrichments' do
      let(:course) do
        create(:course, with_enrichments: [
            [:published, created_at: 5.days.ago],
            [:published, created_at: 3.days.ago],
            [:subsequent_draft, created_at: 1.day.ago],
        ])
      end
      let(:user) { create(:user) }

      it 'publishes the draft' do
        course.publish_enrichment(user)
        course.reload.enrichments.each do |enrichment|
          expect(enrichment).to be_published
        end
      end
    end
  end

  describe '#publish_sites' do
    let(:published_new_site)            { create(:site_status, :published, :new) }
    let(:published_running_site)        { create(:site_status, :published, :running) }
    let(:published_discontinued_site)   { create(:site_status, :published, :discontinued) }
    let(:published_suspended_site)      { create(:site_status, :published, :suspended) }
    let(:unpublished_new_site)          { create(:site_status, :unpublished, :new) }
    let(:unpublished_running_site)      { create(:site_status, :unpublished, :running) }
    let(:unpublished_discontinued_site) { create(:site_status, :unpublished, :discontinued) }
    let(:unpublished_suspended_site)    { create(:site_status, :unpublished, :suspended) }

    before do
      course.publish_sites
    end

    context 'on an old course with a site' do
      let(:course) { create(:course, site_statuses: [published_new_site], age: 5.days.ago) }
      it 'updates course.changed_at' do
        expect(course.changed_at).to be_within(1.second).of Time.now.utc
      end
    end

    context 'on a course with many sites' do
      let(:course) {
        create(:course, site_statuses: [
          published_new_site,
          published_running_site,
          published_discontinued_site,
          published_suspended_site,
          unpublished_new_site,
          unpublished_running_site,
          unpublished_discontinued_site,
          unpublished_suspended_site
        ])
      }

      it 'sets all the sites to the right published/status states' do
        expect(published_new_site.reload).to be_published_on_ucas
        expect(published_new_site).to be_status_running
        expect(published_running_site.reload).to be_published_on_ucas
        expect(published_running_site).to be_status_running
        expect(published_discontinued_site.reload).to be_published_on_ucas
        expect(published_discontinued_site).to be_status_discontinued
        expect(published_suspended_site.reload).to be_published_on_ucas
        expect(published_suspended_site).to be_status_suspended
        expect(unpublished_new_site.reload).to be_published_on_ucas
        expect(unpublished_new_site).to be_status_running
        expect(unpublished_running_site.reload).to be_published_on_ucas
        expect(unpublished_running_site).to be_status_running
        expect(unpublished_discontinued_site.reload).to be_unpublished_on_ucas
        expect(unpublished_discontinued_site).to be_status_discontinued
        expect(unpublished_suspended_site.reload).to be_unpublished_on_ucas
        expect(unpublished_suspended_site).to be_status_suspended
      end
    end
  end
end
