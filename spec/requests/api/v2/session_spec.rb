require "rails_helper"

describe "/api/v2/sessions", type: :request do
  let(:user)    { create(:user) }
  let(:payload) { { email: user.email } }
  let(:token) do
    JWT.encode payload,
               MCBE.authentication.secret,
               MCBE.authentication.algorithm
  end
  let(:credentials) do
    ActionController::HttpAuthentication::Token.encode_credentials(token)
  end

  context "when unauthenticated" do
    let(:payload) { { email: "foo@bar" } }

    before do
      post "/api/v2/sessions",
           headers: { "HTTP_AUTHORIZATION" => credentials }
    end

    subject { response }

    it { should have_http_status(:unauthorized) }
  end

  describe "creating a session" do
    let(:params) do
      {
        "_jsonapi" => {
          "data" => {
            "type" => type,
            "attributes" => attributes,
          },
        },
      }
    end

    context "session resource type" do
      let(:type) { "sessions" }
      let(:attributes) do
        {
          "first_name" => user.first_name,
          "last_name" => user.last_name,
        }
      end

      let(:user) { create(:user, last_login_date_utc: 10.days.ago) }
      let(:returned_json_response) { JSON.parse response.body }

      let(:govuk_notify_request) do
        stub_request(:post, "https://api.notifications.service.gov.uk/v2/notifications/email").
           with(
             body: { email_address: user.email, template_id: MCBE.govuk_notify.welcome_email_template_id, personalisation: { first_name: user.first_name } }.to_json,
            ).
            to_return(status: 200, body: "{}", headers: {})
      end


      before do
        govuk_notify_request
        Timecop.freeze
        post "/api/v2/sessions",
             headers: { "HTTP_AUTHORIZATION" => credentials },
             params: params
      end

      after do
        Timecop.return
      end

      it "saves the last login time" do
        # OS vs TimeCop vs db, most likely db (nanoseconds are omitted), hence
        # 'be_within(1.second).of Time.now.utc' vs 'eq Time.now.utc'
        expect(user.reload.last_login_date_utc).to be_within(1.second).of Time.now.utc
      end

      describe "the returned json" do
        it "has a data section with the correct attributes" do
          data_attributes = returned_json_response["data"]["attributes"]
          expect(data_attributes["email"]).to eq(user.email)
          expect(data_attributes["first_name"]).to eq(user.first_name)
          expect(data_attributes["last_name"]).to eq(user.last_name)
          expect(data_attributes["state"]).to eq(user.state)
        end
      end

      context "new user details" do
        let(:attributes) do
          {
            "first_name" => "updated first_name",
            "last_name" => "updated last_name",
          }
        end

        it "returns the updated user record" do
          expect(returned_json_response["data"]).to have_attribute(:first_name).with_value("updated first_name")
          expect(returned_json_response["data"]).to have_attribute(:last_name).with_value("updated last_name")
        end

        it "updated user details" do
          user.reload
          expect(user.first_name).to eq "updated first_name"
          expect(user.last_name).to eq "updated last_name"
        end
      end

      context "When the user has not received a welcome email" do
        let(:user) { create(:user, welcome_email_date_utc: nil) }

        it "Sends a welcome email to the user" do
          expect(govuk_notify_request).to have_been_made
        end
      end

      context "When the user has received a welcome email" do
        let(:user) { create(:user) }

        it "Does not send a welcome email to the user" do
          expect(govuk_notify_request).not_to have_been_made
        end
      end
    end

    context "unpermitted parameters" do
      let(:type) { "sessions" }
      let(:attributes) do
        {
          "email" => "updated first_name",
        }
      end

      it "returns the user record with old email" do
        expect {
          post "/api/v2/sessions",
               headers: { "HTTP_AUTHORIZATION" => credentials },
               params: params
        }.to raise_error(ActionController::UnpermittedParameters)
      end
    end

    context "invalid resource type" do
      let(:attributes) do
        {
          "first_name" => "update invalid first_name",
          "last_name" => "updated invalid last_name",
        }
      end
      let(:type) { "invalid" }
      let(:returned_json_response) { JSON.parse response.body }

      # session type
      # pp params[:session]
      # <ActionController::Parameters {"type"=>"session", "first_name"=>"update invalid first_name", "last_name"=>"updated invalid last_name"} permitted: false>

      # invalid type
      # pp params[:session]
      #<ActionController::Parameters {"type"=>"invalid", "first_name"=>"update invalid first_name", "last_name"=>"updated invalid last_name"} permitted: false>


      # concerns are "first_name" & "last_name" and not "type" == "session"
      it "raises an error" do
        expect {
          post "/api/v2/sessions",
               headers: { "HTTP_AUTHORIZATION" => credentials },
               params: params
        }.to raise_error(ActionController::BadRequest)
      end

      it "does not update user record" do
        expect {
          post(
            "/api/v2/sessions",
            headers: { "HTTP_AUTHORIZATION" => credentials },
            params: params,
          ) rescue nil
        }.not_to(change { user.reload })
      end
    end

    context "with inactive user" do
      let(:user) { create(:user, :inactive) }
      let(:type) { "sessions" }
      let(:attributes) do
        {
          "first_name" => user.first_name,
          "last_name" => user.last_name,
        }
      end

      it "succeeds" do
        expect(
          post("/api/v2/sessions",
               headers: { "HTTP_AUTHORIZATION" => credentials },
               params: params),
        ).to be(200)
      end
    end
  end

  context "no params" do
    # deserializable_resource :session
    # from jsonapi-rails seems to enforce expectation
    it "does not update user record" do
      expect {
        post(
          "/api/v2/sessions",
          headers: { "HTTP_AUTHORIZATION" => credentials },
        ) rescue nil
      }.not_to(change { user.reload })
    end
  end
end
