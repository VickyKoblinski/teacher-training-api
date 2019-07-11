require 'rails_helper'

describe API::V1::CoursesController, type: :controller do
  describe '#index' do
    # Format we use for changed_since param.
    let(:timestamp_format) { '%FT%T.%6NZ' }

    def format_timestamp(timestamp)
      timestamp.strftime(timestamp_format)
    end

    # Default sensible params used by tests.
    let(:params) do
      {
        changed_since: format_timestamp(changed_since),
        recruitment_year: '2019'
      }
    end

    before do
      allow(controller).to receive(:authenticate)

      # A bit of boilerplate setup since this isn't an integration or
      # functional test. There may be a more standard way of doing this
      # which would be better.
      assigns(:_params).merge! params

      # Stubbing out the data that Rails' url_for relies on is too tricky,
      # so just stub the whole method out.
      allow(controller).to receive(:url_for) do |options = {}|
        'http://test.local/api/v1/course?' + options[:params].to_query
      end
      controller.response = response
    end

    context 'with two courses changed at different times' do
      let(:old_course)  { create(:course, changed_at: 5.minutes.ago.utc) }
      let(:last_course) { create(:course, changed_at: 1.minute.ago.utc) }

      # We need to define the before block after any let! statements since they
      # are run in order of definition: we need to call the controller action
      # after any let! fixtures are created.
      before do
        old_course
        last_course

        controller.index
      end

      context 'using a changed_since before any courses have changed' do
        # Gets placed into params.
        let(:changed_since) { 10.minutes.ago.utc }

        describe 'returned courses in JSON' do
          subject { response.body }

          it {
            should have_courses(old_course, last_course)
          }
        end

        describe 'generated next link' do
          subject do
            # Parse out the query params for testing.
            Rack::Utils.parse_query(URI(response.headers['Link']).query)
          end

          its(%w[per_page]) { should eq '100' }
          its(%w[changed_since]) do
            should eq format_timestamp(last_course.changed_at)
          end
        end
      end

      context 'using a changed_since after any courses have changed' do
        describe 'generated next link' do
          subject do
            # Parse out the query params for testing.
            Rack::Utils.parse_query(URI(response.headers['Link']).query)
          end

          let(:changed_since) { Time.now.utc }

          its(%w[per_page]) { should eq '100' }
          its(%w[changed_since]) { should eq params[:changed_since] }
        end
      end
    end

    context 'with no courses at all' do
      let(:changed_since) { 10.minutes.ago.utc }

      before do
        controller.index
      end

      describe 'returned courses in JSON' do
        subject { response.body }

        it { should_not have_courses }
      end

      describe 'generated next link' do
        subject do
          # Parse out the query params for testing.
          Rack::Utils.parse_query(URI(response.headers['Link']).query)
        end

        let(:changed_since) { DateTime.now.utc }

        its(%w[per_page]) { should eq '100' }
        its(%w[changed_since]) { should eq format_timestamp(changed_since) }
      end
    end

    context "for next recruitment year" do
      let!(:course) { create(:course, provider: provider) }
      let(:provider) { build(:provider, recruitment_cycle: next_cycle) }
      let(:next_cycle) { build(:recruitment_cycle, year: '2020') }
      let(:params) {
        { recruitment_year: '2020' }
      }

      before do
        controller.index
      end

      describe 'returned courses in JSON' do
        subject { response.body }

        it { should include course.course_code }
      end
    end
  end
end
