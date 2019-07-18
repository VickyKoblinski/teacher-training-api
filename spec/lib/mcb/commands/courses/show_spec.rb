require 'mcb_helper'

describe 'mcb courses show' do
  let(:show) { MCBCommand.new('courses', 'show') }

  let(:recruitment_year1) { create :recruitment_cycle, year: '2020' }
  let(:recruitment_year2) { RecruitmentCycle.current_recruitment_cycle }

  let(:provider) { create :provider, updated_at: 1.day.ago, changed_at: 1.day.ago, recruitment_cycle: recruitment_year1 }
  let(:rolled_over_provider) do
    new_provider = provider.dup
    new_provider.update(recruitment_cycle: recruitment_year2)
    new_provider.save
    new_provider
  end

  let(:subject1) { build(:subject) }
  let(:subject2) { build(:subject) }
  let(:site_status1) { build(:site_status) }
  let(:site_status2) { build(:site_status) }

  let(:course) { create(:course, name: 'P', provider: provider, subjects: [subject1], site_statuses: [site_status1]) }
  let(:rolled_over_course) do
    new_course = course.dup
    new_course.update(provider: rolled_over_provider)
    new_course.update(subjects: [subject2])
    new_course.update(site_statuses: [site_status2])
    new_course.save
    new_course
  end

  context 'when the recruitment year is unspecified' do
    it 'displays the course info with the default recruitment year' do
      rolled_over_course

      output = show.execute(arguments: [rolled_over_provider.provider_code, rolled_over_course.course_code])[:stdout]

      expect(output).to have_text_table_row('course_code',
                                            rolled_over_course.course_code)

      expect(output).to have_text_table_row(subject2.subject_code,
                                            subject2.subject_name)

      expect(output).to(
        have_text_table_row(
          site_status2.id,
          site_status2.site.code,
          site_status2.site.location_name,
          site_status2.vac_status,
          site_status2.status,
          site_status2.publish,
          site_status2.applications_accepted_from.strftime('%Y-%m-%d')
        )
      )
    end
  end

  context 'when the recruitment year is specified' do
    it 'displays the course info for the specified recruitment year' do
      rolled_over_course

      output = show.execute(arguments: [provider.provider_code, course.course_code, '-r', recruitment_year1.year])[:stdout]

      expect(output).to have_text_table_row('course_code',
                                            course.course_code)

      expect(output).to have_text_table_row(subject1.subject_code,
                                            subject1.subject_name)

      expect(output).to(
        have_text_table_row(
          site_status1.id,
          site_status1.site.code,
          site_status1.site.location_name,
          site_status1.vac_status,
          site_status1.status,
          site_status1.publish,
          site_status1.applications_accepted_from.strftime('%Y-%m-%d')
        )
      )
    end
  end
end
