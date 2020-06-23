class CourseOldAccreditedBodyChangeEmailMailer < GovukNotifyRails::Mailer
  include TimeFormat

  def course_old_accredited_body_change_email(course, user, datetime)

    set_template(Settings.govuk_notify.course_old_accredited_body_change_email_template_id)

    set_personalisation(
      provider_name: course.provider.provider_name,
      course_name: course.name,
      course_code: course.course_code,
      course_url: create_course_url(course),
      course_change_datetime: gov_uk_format(datetime),
      new_accrediting_body: course.accrediting_provider.provider_name
    )

    mail(to: user.email)
  end

private

  def create_course_url(course)
    "#{Settings.find_url}" \
      "/course/#{course.provider.provider_code}" \
      "/#{course.course_code}"
  end
end
