# TODO: remove this bonkers logic once course mapping is done by one app!
# The user need for this is unclear
module Subjects
  class SecondaryEnglishMapping
    def applicable_to?(ucas_subjects, course_title)
      (ucas_subjects & ucas_english).any? &&
        course_title.index("english") != nil
    end

    def to_dfe_subject
      "English"
    end

  private

    def ucas_english
      ["english",
       "english language",
       "english literature"]
    end
  end
end
