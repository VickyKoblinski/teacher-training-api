require "rails_helper"

describe SubjectUpdateEmailMailer, type: :mailer do
  let(:previous_subject) { create(:primary_subject, :primary_with_english)}
  let(:course) { create(:course, :with_accrediting_provider, name: updated_course_name, updated_at: DateTime.new(2001, 2, 3, 4, 5, 6), subjects:[updated_subject]) }
  let(:user) { create(:user) }
  let(:updated_subject) { create(:primary_subject, :primary_with_mathematics)}
  let(:previous_course_name) {'primary with English'}
  let(:updated_course_name) {'Primary with Mathematics'}

  context "sending an email to a user" do
    let(:mail) do
      described_class.subject_update_email(
        course: course,
        previous_subject: previous_subject.subject_name,
        updated_subject: updated_subject.subject_name,
        previous_course_name: previous_course_name,
        recipient: user,
        )
    end

    before do
      course
      mail
    end

    it "sends an email with the correct template" do
      expect(mail.govuk_notify_template).to eq(Settings.govuk_notify.subject_update_email_template_id)
    end

    it "includes the course name in the personalisation" do
      expect(mail.govuk_notify_personalisation[:course_name]).to eq(course.name)
    end

    it "sends an email to the correct email address" do
      expect(mail.to).to eq([user.email])
    end

    it "includes the course code in the personalisation" do
      expect(mail.govuk_notify_personalisation[:course_code]).to eq(course.course_code)
    end

    it "includes the provider name in the personalisation" do
      expect(mail.govuk_notify_personalisation[:provider_name]).to eq(course.provider.provider_name)
    end

    it "includes the datetime for the detail update in the personalisation" do
      expect(mail.govuk_notify_personalisation[:subject_change_datetime]).to eq("4:05am on 3 February 2001")
    end

    it "includes the updated subject" do
      expect(mail.govuk_notify_personalisation[:updated_subject]).to eq(updated_subject.subject_name)
    end

    it "includes the previous subject" do
      expect(mail.govuk_notify_personalisation[:previous_subject]).to eq(previous_subject.subject_name)
    end

    it "includes the updated course name" do
      expect(mail.govuk_notify_personalisation[:updated_course_name]).to eq(updated_course_name)
    end

    it "includes the previous course name" do
      expect(mail.govuk_notify_personalisation[:previous_course_name]).to eq(previous_course_name)
    end
  end
end
