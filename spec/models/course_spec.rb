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
  let(:course) { create(:course, name: 'Biology', course_code: '3X9F') }
  let(:subject) { course }

  its(:to_s) { should eq('Biology (3X9F)') }
  its(:modular) { should eq('') }

  describe 'auditing' do
    it { should be_audited }
    it { should have_associated_audits }
  end

  describe 'associations' do
    it { should belong_to(:provider) }
    it { should belong_to(:accrediting_provider).optional }
    it { should have_many(:subjects).through(:course_subjects) }
    it { should have_many(:site_statuses) }
    it { should have_many(:sites) }
    it { should have_many(:enrichments) }
  end

  describe 'validations' do
    it { should validate_uniqueness_of(:course_code).scoped_to(:provider_id) }

    describe 'valid?' do
      let(:course) { create(:course, enrichments: [invalid_enrichment]) }
      let(:invalid_enrichment) { build(:course_enrichment, about_course: '') }

      before do
        subject
        invalid_enrichment.about_course = Faker::Lorem.sentence(1000)
        subject.valid?
      end

      it 'should add enrichment errors' do
        expect(subject.errors.full_messages).to_not be_empty
      end
    end

    describe 'publishable?' do
      let(:course) { create(:course, enrichments: [invalid_enrichment]) }
      let(:invalid_enrichment) { create(:course_enrichment, about_course: '') }

      before do
        subject.publishable?
      end

      it 'should add enrichment errors' do
        expect(subject.errors.full_messages).to_not be_empty
      end
    end
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

  its(:recruitment_cycle) { should eq find(:recruitment_cycle) }

  describe 'no site statuses' do
    its(:site_statuses) { should be_empty }
    its(:findable?) { should be false }
    its(:open_for_applications?) { should be false }
    its(:has_vacancies?) { should be false }
  end

  context "with sites" do
    let(:first_site) { create(:site) }
    let(:first_site_status) { create(:site_status, :running, site: first_site) }
    let(:second_site) { create(:site) }
    let(:second_site_status) { create(:site_status, :suspended, site: second_site) }
    let(:new_site) { create(:site) }

    subject { create(:course, site_statuses: [first_site_status, second_site_status]) }

    describe "#sites" do
      it "should only return new and running sites" do
        expect(subject.sites.to_a).to eq([first_site])
      end
    end

    describe "sites=" do
      before do
        subject.sites = [second_site, new_site]
      end

      it "should assign new sites" do
        expect(subject.sites.to_a).to eq([second_site, new_site])
      end

      it "should set old site_status to suspended" do
        expect(first_site_status.reload.status).to eq("suspended")
      end
    end
  end

  context 'with site statuses' do
    let(:findable) { build(:site_status, :findable) }
    let(:with_any_vacancy) { build(:site_status, :with_any_vacancy) }
    let(:default) { build(:site_status) }
    let(:applications_being_accepted_now) { build(:site_status, :applications_being_accepted_now) }
    let(:applications_being_accepted_in_future) { build(:site_status, :applications_being_accepted_in_future) }
    let(:site_status_with_no_vacancies) { build(:site_status, :with_no_vacancies) }
    describe 'findable?' do
      context 'with at least one site status as findable' do
        context 'single site status as findable' do
          let(:subject) { create(:course, site_statuses: [findable]) }

          its(:site_statuses) { should_not be_empty }
          its(:findable?) { should be true }
        end

        context 'single site status as findable and mix site status as non findable' do
          let(:subject) {
            create(:course, site_statuses: [findable,
                                            with_any_vacancy,
                                            default,
                                            applications_being_accepted_now,
                                            applications_being_accepted_in_future])
          }

          its(:site_statuses) { should_not be_empty }
          its(:findable?) { should be true }
        end
      end
    end

    describe '#has_vacancies?' do
      let(:findable_without_vacancies) { build(:site_status, :findable, :with_no_vacancies) }
      context 'for a single site status that has vacancies' do
        let(:subject) {
          create(:course, site_statuses: [findable, applications_being_accepted_now, with_any_vacancy])
        }

        its(:has_vacancies?) { should be true }
      end

      context 'for a site status with vacancies and others without' do
        let(:findable_with_vacancies) { build(:site_status, :findable, :with_any_vacancy, :applications_being_accepted_now) }
        let(:subject) {
          create(:course, site_statuses: [findable_with_vacancies, findable_without_vacancies])
        }

        its(:has_vacancies?) { should be true }
      end

      context 'when none of the sites have vacancies' do
        let(:subject) {
          create(:course, site_statuses: [findable_without_vacancies, findable_without_vacancies])
        }

        its(:has_vacancies?) { should be false }
      end

      context 'when the site is findable but only opens in the future' do
        let(:findable_with_vacancies) { build(:site_status, :findable, :with_any_vacancy, :applications_being_accepted_in_future) }
        let(:subject) {
          create(:course, site_statuses: [findable_with_vacancies])
        }
        its(:has_vacancies?) { should be true }
      end

      context 'when only discontinued and suspended site statuses have vacancies' do
        let(:findable_with_no_vacancies) { build(:site_status, :findable, :with_no_vacancies) }
        let(:published_suspended_with_any_vacancy) { build(:site_status, :published, :discontinued, :with_any_vacancy) }
        let(:published_discontinued_with_any_vacancy) { build(:site_status, :published, :suspended, :with_any_vacancy) }

        let(:subject) {
          create(:course, site_statuses: [findable_with_no_vacancies, published_suspended_with_any_vacancy, published_discontinued_with_any_vacancy])
        }

        its(:has_vacancies?) { should be false }
      end
    end

    describe 'open_for_applications?' do
      context 'with at least one site status applications_being_accepted_now' do
        context 'single site status applications_being_accepted_now as it open now' do
          let(:findable_with_vacancies) { build(:site_status, :findable, :with_any_vacancy, :applications_being_accepted_now) }
          let(:subject) {
            create(:course, site_statuses: [findable_with_vacancies])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be true }
        end

        context 'single site status applications_being_accepted_now as it open future' do
          let(:subject) {
            create(:course, site_statuses: [applications_being_accepted_in_future])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be false }
        end

        context 'site statuses applications_being_accepted_now as it open now & future' do
          let(:findable_with_vacancies_now) { build(:site_status, :findable, :with_any_vacancy, :applications_being_accepted_now) }
          let(:findable_with_vacancies_in_future) { build(:site_status, :findable, :with_any_vacancy, :applications_being_accepted_in_future) }
          let(:subject) {
            create(:course, site_statuses: [findable_with_vacancies_now, findable_with_vacancies_in_future])
          }

          its(:site_statuses) { should_not be_empty }
          its(:open_for_applications?) { should be true }
        end
      end
    end

    describe 'ucas_status' do
      context 'without any site statuses' do
        let(:subject) { create(:course) }

        its(:ucas_status) { should eq :new }
      end

      context 'with a running site_status' do
        let(:subject) { create(:course, site_statuses: [findable]) }

        its(:ucas_status) { should eq :running }
      end

      context 'with a new site_status' do
        let(:new) { build(:site_status, :new) }
        let(:subject) { create(:course, site_statuses: [new]) }

        its(:ucas_status) { should eq :new }
      end

      context 'with a not running site_status' do
        let(:suspended) { build(:site_status, :suspended) }
        let(:subject) { create(:course, site_statuses: [suspended]) }

        its(:ucas_status) { should eq :not_running }
      end
    end

    its(:site_statuses) { should be_empty }
    its(:findable?) { should be false }
    its(:open_for_applications?) { should be false }
    its(:has_vacancies?) { should be false }
  end

  describe '#by_recruitment_cycle' do
    context 'with valid recruitment_year parameter' do
      let(:current_cycle) { create(:recruitment_cycle, year: '2019') }
      let(:next_cycle) { create(:recruitment_cycle, year: '2020') }
      let(:provider_1) { create(:provider, recruitment_cycle: current_cycle) }
      let(:provider_2) { create(:provider, recruitment_cycle: next_cycle) }
      let(:course_1) { create(:course, provider: provider_1) }
      let(:course_2) { create(:course, provider: provider_2) }

      subject { Course.by_recruitment_cycle('2019') }

      it { should include course_1 }
      it { should_not include course_2 }
    end
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

  context "subjects & level" do
    context 'with no subjects' do
      subject { create(:course) }
      its(:level) { should eq(:secondary) }
      its(:dfe_subjects) { should be_empty }
    end

    context 'with primary subjects' do
      subject { create(:course, subjects: [find_or_create(:subject, :primary)]) }
      its(:level) { should eq(:primary) }
      its(:dfe_subjects) { should eq([DFESubject.new("Primary")]) }
    end

    context 'with secondary subjects' do
      subject { create(:course, subjects: [find_or_create(:subject, subject_name: "physical education")]) }
      its(:level) { should eq(:secondary) }
      its(:dfe_subjects) { should eq([DFESubject.new("Physical education")]) }
    end

    context 'with further education subjects' do
      subject { create(:course, subjects: [create(:further_education_subject)]) }
      its(:level) { should eq(:further_education) }
      its(:dfe_subjects) { should eq([DFESubject.new("Further education")]) }
    end

    describe "#is_send?" do
      subject { create(:course) }
      its(:is_send?) { should be_falsey }

      context "with a SEND subject" do
        subject { create(:course, subjects: [create(:send_subject)]) }
        its(:is_send?) { should be_truthy }
      end
    end

    describe "bursaries and scholarships" do
      let(:subjects) {
        [
          build(:subject, :mathematics),
          build(:subject, :secondary),
        ]
      }
      subject { create(:course, subjects: subjects) }

      it { should have_bursary }
      it { should have_scholarship_and_bursary }
    end
  end

  context "entry requirements" do
    %i[maths science english].each do |gcse_subject|
      describe gcse_subject do
        it 'is an enum' do
          expect(subject)
            .to define_enum_for(gcse_subject)
                  .backed_by_column_of_type(:integer)
                  .with_values(Course::ENTRY_REQUIREMENT_OPTIONS)
                  .with_suffix("for_#{gcse_subject}")
        end
      end
    end
  end

  describe "#applications_open_from=" do
    let(:provider) { build(:provider, sites: [sites]) }
    let(:sites) { build_list(:site, 3) }
    let!(:existing_site_status) {
      sites.each do |site|
        create(:site_status,
               :running,
               site: site,
               course: subject,
               applications_accepted_from: Date.new(2018, 10, 9))
      end
    }

    it "updates the applications_accepted_from date on the site statuses" do
      expect { subject.applications_open_from = Date.new(2018, 10, 23) }.
        to change { subject.reload.site_statuses.pluck(:applications_accepted_from).uniq }.
        from([Date.new(2018, 10, 9)]).to([Date.new(2018, 10, 23)])
    end
  end

  describe "adding and removing sites on a course" do
    let(:provider) { build(:provider) }
      #this code will be removed and fixed properly in the next pr
    let(:new_site) { create(:site, provider: provider, code: 'A') }
     #this code will be removed and fixed properly in the next pr
    let(:existing_site) { create(:site, provider: provider, code: 'B') }
    let(:new_site_status) { subject.site_statuses.find_by!(site: new_site) }
    subject { create(:course, site_statuses: [existing_site_status]) }

    context "for running courses" do
      let(:existing_site_status) { create(:site_status, :running, :published, site: existing_site) }

      it "suspends the site when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("running").to("suspended")
      end

      it "adds a new site status and sets it to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("running")
      end
    end

    context "for new courses" do
      let(:existing_site_status) { create(:site_status, :new, site: existing_site) }

      it "sets the site to new when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("new_status")
      end

      it "keeps the site status as new when an existing site is added" do
        expect { subject.add_site!(site: existing_site) }.
          to_not change { existing_site_status.reload.status }.from("new_status")
      end

      it "removes the site status when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(0)
      end
    end

    context "for suspended courses" do
      let(:existing_site_status) { create(:site_status, :suspended, site: existing_site) }

      it "sets the site to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("running")
      end

      it "sets the site to running when an existing site is added" do
        expect { subject.add_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("suspended").to("running")
      end
    end

    context "for courses without any training locations" do
      subject { create(:course, site_statuses: []) }

      it "sets the site to new when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(0).to(1)
        expect(new_site_status.status).to eq("new_status")
      end
    end

    context "for mixed courses with new and running locations" do
      let(:existing_site_status) { create(:site_status, :running, :published, site: existing_site) }
      #this code will be removed and fixed properly in the next pr
      let(:another_existing_site) { create(:site, code: 'C', provider: provider) }
      let(:existing_new_site_status) { create(:site_status, :new, site: another_existing_site) }

      subject { create(:course, site_statuses: [existing_site_status, existing_new_site_status]) }

      it "adds a new site status and sets it to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(2).to(3)
        expect(new_site_status.status).to eq("running")
      end

      it "suspends the site when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("running").to("suspended")
      end
    end
  end

  describe '#accrediting_provider_description' do
    let(:accrediting_provider) { nil }
    let(:course) { create(:course, accrediting_provider: accrediting_provider) }
    subject { course.accrediting_provider_description }

    context 'for courses without accrediting provider' do
      it { should be_nil }
    end

    context 'for courses with accrediting provider' do
      let(:accrediting_provider) { build(:provider) }

      context 'without published enrichment' do
        it { should be_nil }
      end

      context 'with published enrichment' do
        let(:provider_enrichment) { build(:provider_enrichment, :published, last_published_at: 1.day.ago) }
        let(:provider) { build(:provider, enrichments: [provider_enrichment]) }
        let(:course) { create(:course, provider: provider, accrediting_provider: accrediting_provider) }

        context 'without any accrediting_provider_enrichments' do
          it { should be_nil }
        end

        context "with accrediting_provider_enrichments" do
          let(:accrediting_provider_enrichment_description) { Faker::Lorem.sentence.to_s }
          let(:accrediting_provider_enrichment) do
            {
              'UcasProviderCode' => accrediting_provider.provider_code,
              'Description' => accrediting_provider_enrichment_description
            }
          end

          let(:accrediting_provider_enrichments) { [accrediting_provider_enrichment] }
          let(:provider_enrichment) do
            build(:provider_enrichment,
                  :published,
                  last_published_at: 1.day.ago,
                  accrediting_provider_enrichments: accrediting_provider_enrichments)
          end

          it { should match accrediting_provider_enrichment_description }
        end
      end
    end
  end

  describe '#enrichments' do
    describe '#find_or_initialize_draft' do
      let(:course) { create(:course, enrichments: enrichments) }

      copyable_enrichment_attributes =
        %w[
          about_course
          course_length
          fee_details
          fee_international
          fee_uk_eu
          financial_support
          how_school_placements_work
          interview_process
          other_requirements
          personal_qualities
          qualifications
          salary_details
        ].freeze

      let(:actual_enrichment_attributes) do
        subject.attributes.slice(*copyable_enrichment_attributes)
      end

      subject { course.enrichments.find_or_initialize_draft }

      context 'no enrichments' do
        let(:enrichments) { [] }

        it "sets all attributes to be nil" do
          expect(actual_enrichment_attributes.values).to be_all(&:nil?)
        end

        its(:id) { should be_nil }
        its(:last_published_timestamp_utc) { should be_nil }
        its(:status) { should eq 'draft' }
      end

      context 'with a draft enrichment' do
        let(:initial_draft_enrichment) { build(:course_enrichment, :initial_draft) }
        let(:enrichments) { [initial_draft_enrichment] }
        let(:expected_enrichment_attributes) { initial_draft_enrichment.attributes.slice(*copyable_enrichment_attributes) }

        it "has all the same attributes as the initial draft enrichment" do
          expect(actual_enrichment_attributes).to eq expected_enrichment_attributes
        end

        its(:id) { should_not be_nil }
        its(:last_published_timestamp_utc) { should eq initial_draft_enrichment.last_published_timestamp_utc }
        its(:status) { should eq 'draft' }
      end

      context 'with a published enrichment' do
        let(:published_enrichment) { build(:course_enrichment, :published) }
        let(:enrichments) { [published_enrichment] }
        let(:expected_enrichment_attributes) { published_enrichment.attributes.slice(*copyable_enrichment_attributes) }

        it "has all the same attributes as the published enrichment" do
          expect(actual_enrichment_attributes).to eq expected_enrichment_attributes
        end

        its(:id) { should be_nil }
        its(:last_published_timestamp_utc) { should be_within(1.second).of published_enrichment.last_published_timestamp_utc }
        its(:status) { should eq 'draft' }
      end

      context 'with a draft and published enrichment' do
        let(:published_enrichment) { build(:course_enrichment, :published) }
        let(:subsequent_draft_enrichment) { build(:course_enrichment, :subsequent_draft) }
        let(:enrichments) { [published_enrichment, subsequent_draft_enrichment] }
        let(:expected_enrichment_attributes) { subsequent_draft_enrichment.attributes.slice(*copyable_enrichment_attributes) }

        it "has all the same attributes as the subsequent draft enrichment" do
          expect(actual_enrichment_attributes).to eq expected_enrichment_attributes
        end

        its(:id) { should_not be_nil }
        its(:last_published_timestamp_utc) { should be_within(1.second).of subsequent_draft_enrichment.last_published_timestamp_utc }
        its(:status) { should eq 'draft' }
      end
    end
  end

  describe '#syncable?' do
    let(:courses_subjects) { [build(:subject, subject_name: "primary")] }
    let(:site_status) { build(:site_status, :findable) }

    subject { create(:course, subjects: courses_subjects, site_statuses: [site_status]) }

    its(:syncable?) { should be_truthy }

    context'invalid courses' do
      context 'course which has a dfe subject, but no findable site statuses' do
        let(:site_status) { build(:site_status, :suspended) }
        its(:syncable?) { should be_falsey }
      end

      context 'course which has a findable site status, but no dfe_subject' do
        let(:courses_subjects) { [build(:subject, subject_name: "secondary")] }
        its(:syncable?) { should be_falsey }
      end
    end
  end
end
