module Courses
  module EditCourseOptions
    module QualificationOptions
      extend ActiveSupport::Concern
      included do
        def qualification_options(course)
          qualifications_with_qts, qualifications_without_qts = Course::qualifications.keys.partition { |q| q.include?('qts') }
          course.level == :further_education ? qualifications_without_qts : qualifications_with_qts
        end
      end
    end
  end
end
