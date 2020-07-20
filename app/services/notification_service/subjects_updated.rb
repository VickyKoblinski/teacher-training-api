module NotificationService
  class SubjectsUpdated
    include ServicePattern

    def initialize(course:, previous_subject:, updated_subject:, previous_course_name:)
      @course = course
      @previous_subject = previous_subject
      @updated_subject = updated_subject
      @previous_course_name = previous_course_name
    end

    def call
      return false unless notify_accredited_body?
      return false unless course.in_current_cycle?

      users = User.joins(:user_notifications).merge(UserNotification.course_update_notification_requests(course.accredited_body_code))

      users.each do |user|
        SubjectUpdateEmailMailer.subject_update_email(
          course: course,
          previous_subject: previous_subject.subject_name,
          updated_subject: updated_subject.subject_name,
          previous_course_name: previous_course_name,
          recipient: user,
        ).deliver_later(queue: "mailer")
      end
    end

  private

    attr_reader :course, :updated_subject, :previous_subject, :previous_course_name

    def notify_accredited_body?
      return false if course.self_accredited?
      return false unless course.findable?

      true
    end
  end
end
