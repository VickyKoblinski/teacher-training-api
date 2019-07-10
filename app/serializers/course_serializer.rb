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

class CourseSerializer < ActiveModel::Serializer
  has_many :site_statuses, key: :campus_statuses
  has_many :subjects
  has_one :provider, serializer: CourseProviderSerializer
  has_one :accrediting_provider, serializer: CourseProviderSerializer

  attributes :course_code, :start_month, :name, :study_mode, :copy_form_required, :profpost_flag,
             :program_type, :modular, :english, :maths, :science, :recruitment_cycle,
             :start_month_string, :age_range

  def profpost_flag
    object.profpost_flag_before_type_cast
  end

  def program_type
    object.program_type_before_type_cast
  end

  def study_mode
    object.study_mode_before_type_cast
  end

  def age_range
    object.age_range_before_type_cast
  end

  def maths
    object.maths_before_type_cast
  end

  def english
    object.english_before_type_cast
  end

  def science
    object.science_before_type_cast
  end

  def start_month
    object.start_date.iso8601 if object.start_date
  end

  def start_month_string
    object.start_date.strftime("%B") if object.start_date
  end

  def copy_form_required
    "Y" # we want to always create PDFs for applications coming in
  end

  def recruitment_cycle
    object.recruitment_cycle.year
  end
end
