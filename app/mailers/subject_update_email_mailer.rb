class SubjectUpdateEmailMailer < GovukNotifyRails::Mailer
  include TimeFormat

  def subject_update_email(
    course:,
    previous_subject:,
    updated_subject:,
    previous_course_name:,
    recipient:
  )
    set_template(Settings.govuk_notify.subject_update_email_template_id)


    set_personalisation(
      provider_name: course.provider.provider_name,
      course_name: course.name,
      course_code: course.course_code,
      subject_change_datetime: gov_uk_format(course.updated_at),
      course_url: create_course_url(course),
      previous_subject: previous_subject,
      updated_subject: updated_subject,
      previous_course_name: previous_course_name,
      updated_course_name: course.name
    )

    mail(to: recipient.email)
  end

private

  def create_course_url(course)
    "#{Settings.find_url}" \
      "/course/#{course.provider.provider_code}" \
      "/#{course.course_code}"
  end
end
