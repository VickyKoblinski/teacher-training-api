module NotificationService
  class CourseWithdrawn
    include ServicePattern

    def initialize(course:)
      @course = course
    end

    def call
      return false unless notify_accredited_body?
      return false unless course.in_current_cycle?

      # Reusing existing scoping as we're doing all or nothing notifications atm
      # for course_publish_notification_requests
      users = User.joins(:user_notifications).merge(UserNotification.course_publish_notification_requests(course.accredited_body_code))

      users.each do |user|
        CourseWithdrawEmailMailer.course_withdraw_email(
          course,
          user,
          DateTime.now,
        ).deliver_later(queue: "mailer")
      end
    end

  private

    attr_reader :course

    def notify_accredited_body?
      return false if course.self_accredited?

      true
    end
  end
end
