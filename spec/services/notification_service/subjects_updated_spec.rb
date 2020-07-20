require "rails_helper"

module NotificationService
  describe SubjectsUpdated do
    describe "#call" do
      let(:accredited_body) { create(:provider, :accredited_body) }
      let(:other_accredited_body) { create(:provider, :accredited_body) }
      let(:course) { create(:course, accredited_body_code: accredited_body.provider_code) }
      let(:previous_subject_names) {['primary with english']}
      let(:updated_subject_names) {['primary with mathematics']}
      let(:previous_course_name) { previous_subject_names.first }

      let(:subscribed_user) { create(:user) }
      let(:non_subscribed_user) { create(:user) }
      let(:user_subscribed_to_other_provider) { create(:user) }

      let(:subscribed_notification) do
        create(
          :user_notification,
          user: subscribed_user,
          course_update: true,
          provider_code: accredited_body.provider_code,
        )
      end

      let(:non_subscribed_notification) do
        create(
          :user_notification,
          user: non_subscribed_user,
          course_update: false,
          provider_code: accredited_body.provider_code,
        )
      end

      let(:other_provider_notification) do
        create(
          :user_notification,
          user: user_subscribed_to_other_provider,
          course_publish: true,
          provider_code: other_accredited_body.provider_code,
        )
      end
      let(:self_accredited) { false }
      let(:findable) { true }

      def setup_notifications
        allow(SubjectUpdateEmailMailer).to receive(:subject_update_email).and_return(double(deliver_later: true))
        subscribed_notification
        non_subscribed_notification
        other_provider_notification
        allow(course).to receive(:self_accredited?).and_return(self_accredited)
        allow(course).to receive(:findable?).and_return(findable)
      end

      context "with a course that is in the current cycle" do
        before { setup_notifications }

        it "sends notifications" do
          expect(SubjectUpdateEmailMailer).to receive(:subject_update_email)
          expect(course.recruitment_cycle).to eql(RecruitmentCycle.current)
          described_class.call(
            course: course,
            previous_subject_names: previous_subject_names,
            updated_subject_names: updated_subject_names,
            previous_course_name: previous_course_name
          )
        end
      end

      context "with a course that is not in the current cycle" do
        let(:provider) { create(:provider, :next_recruitment_cycle) }
        let(:course) { create(:course, accredited_body_code: accredited_body.provider_code, provider: provider) }

        before { setup_notifications }

        it "does not send a notification" do
          expect(SubjectUpdateEmailMailer).to_not receive(:subject_update_email)
          expect(course.recruitment_cycle).to_not eql(RecruitmentCycle.current)
          described_class.call(
            course: course,
            previous_subject_names: previous_subject_names,
            updated_subject_names: updated_subject_names,
            previous_course_name: previous_course_name
          )
        end
      end

      context "non self-accredited course" do
        before { setup_notifications }

        context "that is findable" do
          it "mails subscribed users" do
            expect(SubjectUpdateEmailMailer)
              .to receive(:subject_update_email)
              .with(
              course: course,
              previous_subject_names: previous_subject_names,
              updated_subject_names: updated_subject_names,
              previous_course_name: previous_course_name,
              recipient: subscribed_user,).and_return(mailer = double)
            expect(mailer).to receive(:deliver_later).with(queue: "mailer")

            described_class.call(
              course: course,
              previous_subject_names: previous_subject_names,
              updated_subject_names: updated_subject_names,
              previous_course_name: previous_course_name
            )
          end

          it "does not email non subscribed users" do
            expect(SubjectUpdateEmailMailer).not_to receive(:subject_update_email)
              .with(course, non_subscribed_user)
            expect(SubjectUpdateEmailMailer).not_to receive(:subject_update_email)
              .with(course, user_subscribed_to_other_provider)
            described_class.call(
              course: course,
              previous_subject_names: previous_subject_names,
              updated_subject_names: updated_subject_names,
              previous_course_name: previous_course_name
            )
          end
        end

        context "that is not findable?" do
          let(:findable) { false }

          it "does not mail subscribed users" do
            expect(SubjectUpdateEmailMailer)
              .not_to receive(:subject_update_email)
            described_class.call(
              course: course,
              previous_subject_names: previous_subject_names,
              updated_subject_names: updated_subject_names,
              previous_course_name: previous_course_name
            )
          end
        end
      end

      context "self accredited course" do
        let(:self_accredited) { true }

        before { setup_notifications }

        it "does not mail subscribed users" do
          expect(SubjectUpdateEmailMailer)
            .not_to receive(:subject_update_email)

          described_class.call(
            course: course,
            previous_subject_names: previous_subject_names,
            updated_subject_names: updated_subject_names,
            previous_course_name: previous_course_name
          )
        end
      end
    end
  end
end
