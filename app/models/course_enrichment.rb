# == Schema Information
#
# Table name: course_enrichment
#
#  id                           :integer          not null, primary key
#  created_by_user_id           :integer
#  created_at                   :datetime         not null
#  provider_code                :text             not null
#  json_data                    :jsonb
#  last_published_timestamp_utc :datetime
#  status                       :integer          not null
#  ucas_course_code             :text             not null
#  updated_by_user_id           :integer
#  updated_at                   :datetime         not null
#

class CourseEnrichment < ApplicationRecord
  include TouchCourse

  enum status: %i[draft published]

  jsonb_accessor :json_data,
                 about_course: [:string, store_key: 'AboutCourse'],
                 course_length: [:string, store_key: 'CourseLength'],
                 fee_details: [:string, store_key: 'FeeDetails'],
                 fee_international: [:string, store_key: 'FeeInternational'],
                 fee_uk_eu: [:string, store_key: 'FeeUkEu'],
                 financial_support: [:string, store_key: 'FinancialSupport'],
                 how_school_placements_work: [:string,
                                              store_key: 'HowSchoolPlacementsWork'],
                 interview_process: [:string, store_key: 'InterviewProcess'],
                 other_requirements: [:string, store_key: 'OtherRequirements'],
                 personal_qualities: [:string, store_key: 'PersonalQualities'],
                 qualifications: [:string, store_key: 'Qualifications'],
                 salary_details: [:string, store_key: 'SalaryDetails']

  belongs_to :provider, foreign_key: :provider_code, primary_key: :provider_code
  belongs_to :course,
             ->(enrichment) { where(provider_id: enrichment.provider.id) },
             foreign_key: :ucas_course_code,
             primary_key: :course_code

  scope :latest_first, -> { order(created_at: :desc) }

  validates :about_course, word_count: { max_word_count: 400 }, on: :publish
  validates :interview_process, word_count: { max_word_count: 250 }, on: :publish
  validates :how_school_placements_work, word_count: { max_word_count: 350 }, on: :publish
  validates :about_course, word_count: { max_word_count: 400 }, on: :publish

  # salary vs fee needs forking
  validates :fee_international, :fee_uk_eu, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100000 }, on: :publish
  validates :fee_uk_eu, presence: true, on: :publish
  validates :salary_details, presence: true, on: :publish
  validates :fee_details, word_count: { max_word_count: 250 }, on: :publish
  validates :salary_details, word_count: { max_word_count: 250 }, on: :publish
  validates :financial_support, word_count: { max_word_count: 250 }, on: :publish


  def publishable?; end

  def has_been_published_before?
    last_published_timestamp_utc.present?
  end

  def publish(current_user)
    update(status: 'published',
          last_published_timestamp_utc: Time.now.utc,
          updated_by_user_id: current_user.id)
  end

  def unpublish(initial_draft: true)
    data = { status: :draft }
    data[:last_published_timestamp_utc] = nil if initial_draft
    update(data)
  end
end
