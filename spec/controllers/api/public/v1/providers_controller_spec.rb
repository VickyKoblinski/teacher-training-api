require "rails_helper"

RSpec.describe API::Public::V1::ProvidersController do
  describe "#index" do
    let(:recruitment_cycle) { find_or_create :recruitment_cycle }

    context "when there are no providers" do
      before do
        get :index, params: {
          recruitment_cycle_year: recruitment_cycle.year,
        }
      end

      it "returns empty array of data" do
        expect(json_response["data"]).to eql([])
      end
    end

    context "when there are providers" do
      let(:organisation) { create(:organisation) }
      let(:contact) { build(:contact) }

      let(:provider) do
        create(:provider,
               provider_code: "1AT",
               provider_name: "First",
               organisations: [organisation],
               contacts: [contact])
      end

      before do
        provider
      end

      context "successful response" do
        before do
          get :index, params: {
            recruitment_cycle_year: recruitment_cycle.year,
          }
        end

        it "returns correct number of providers for the current cycle" do
          parsed_provider_id = json_response["data"][0]["id"].to_i
          expect(json_response["data"].size).to eql(1)
          expect(parsed_provider_id).to eq(provider.id)
        end

        context "with next recruitment cycle specified" do
          let(:next_recruitment_cycle) { create :recruitment_cycle, :next }
          let(:next_provider) do
            create :provider,
                   organisations: [organisation],
                   provider_code: provider.provider_code,
                   recruitment_cycle: next_recruitment_cycle
          end

          before do
            next_provider

            get :index, params: {
              recruitment_cycle_year: next_recruitment_cycle.year,
            }
          end

          it "returns correct number of providers for the next recruitment cycle" do
            parsed_provider_id = json_response["data"][0]["id"].to_i
            expect(parsed_provider_id).to eq(next_provider.id)
          end
        end
      end

      context "with pagination" do
        before do
          recruitment_cycle.providers << build_list(:provider, 6, organisations: [organisation], contacts: [contact])

          get :index, params: {
            recruitment_cycle_year: recruitment_cycle.year,
            page: {
              page: 2,
              per_page: 5,
            },
          }
        end

        it "can pagingate to page 2" do
          expect(json_response["data"].size).to eql(2)
        end
      end

      context "with includes" do
        before do
          get :index, params: {
            recruitment_cycle_year: recruitment_cycle.year,
            include: "recruitment_cycle",
          }
        end

        it "returns the requested associated data in the response" do
          relationships = json_response["data"][0]["relationships"]
          recruitment_cycle_id = relationships.dig("recruitment_cycle", "data", "id").to_i

          expect(json_response["data"][0]["relationships"].keys.sort).to eq(
            %w[recruitment_cycle],
          )

          expect(recruitment_cycle_id).to eq(provider.recruitment_cycle.id)
        end
      end

      context "with sorting" do
        let(:provider2) do
          create(:provider,
                 provider_code: "0AT",
                 provider_name: "Before",
                 organisations: [organisation],
                 contacts: [contact])
        end

        let(:provider3) do
          create(:provider,
                 provider_code: "2AT",
                 provider_name: "Second",
                 organisations: [organisation],
                 contacts: [contact])
        end

        let(:provider_names_in_response) do
          json_response["data"].map do |provider|
            provider["attributes"]["name"]
          end
        end

        before do
          provider2
          provider3
        end

        context "default ordering" do
          before do
            get :index, params: {
              recruitment_cycle_year: recruitment_cycle.year,
            }
          end

          it "returns them in a-z order" do
            expect(provider_names_in_response).to eq(%w[Before First Second])
          end
        end

        context "passing in sort param" do
          before do
            get :index, params: {
              recruitment_cycle_year: recruitment_cycle.year,
              sort: sort_field,
            }
          end

          context "name" do
            let(:sort_field) { "name" }

            it "returns them in a-z order" do
              expect(provider_names_in_response).to eq(%w[Before First Second])
            end
          end

          context "-name" do
            let(:sort_field) { "-name" }

            it "returns them in z-a order" do
              expect(provider_names_in_response).to eq(%w[Second First Before])
            end
          end

          context "name,-name" do
            let(:sort_field) { "name,-name" }

            it "returns them in a-z order" do
              expect(provider_names_in_response).to eq(%w[Before First Second])
            end
          end

          context "-name,name" do
            let(:sort_field) { "-name,name" }

            it "returns them in a-z order" do
              expect(provider_names_in_response).to eq(%w[Before First Second])
            end
          end
        end
      end

      context "with sparse fields" do
        context "when specific fields are specified" do
          before do
            get :index, params: {
              recruitment_cycle_year: recruitment_cycle.year,
              fields: {
                providers: "name",
              },
            }
          end

          it "returns only specified fields" do
            expect(json_response["data"].first["attributes"].keys.count).to eq(1)
            expect(json_response["data"].first).to have_attribute("name")
          end
        end

        context "default fields" do
          let(:fields) do
            %w[ postcode
                provider_type
                region_code
                train_with_disability
                train_with_us
                website
                accredited_body
                changed_at
                city
                code
                county
                created_at
                name
                street_address_1
                street_address_2]
          end

          before do
            get :index, params: {
              recruitment_cycle_year: recruitment_cycle.year,
            }
          end

          it "returns the default fields" do
            expect(json_response["data"].first["attributes"].keys).to match_array(fields)
          end
        end
      end
    end
  end

  describe "#show" do
    let(:provider) { create(:provider) }
    let(:recruitment_cycle_year) { provider.recruitment_cycle.year }
    let(:provider_code) { provider.provider_code }

    before do
      provider
    end

    context "with unknown provider code" do
      let(:provider_code) { "unknown" }
      let(:data) { nil }

      before do
        get :show, params: {
          recruitment_cycle_year: recruitment_cycle_year,
          code: provider_code,
        }
      end

      it { expect(response).to have_http_status(:not_found) }

      it "returns nil in the data attribute" do
        expect(json_response["data"]).to be_nil
      end
    end

    context "with correct provider code" do
      let(:expected_data) do
        {
          "id" => provider.id.to_s,
          "type" => "providers",
          "attributes" => {
            "code" => provider.provider_code,
            "name" => provider.provider_name,
            "postcode" => provider.postcode,
            "provider_type" => provider.provider_type,
            "region_code" => provider.region_code,
            "train_with_disability" => provider.train_with_disability,
            "train_with_us" => provider.train_with_us,
            "website" => provider.website,
            "accredited_body" => provider.accredited_body?,
            "changed_at" => provider.changed_at.iso8601,
            "city" => provider.address3,
            "county" => provider.address4,
            "created_at" => provider.created_at.iso8601,
            "street_address_1" => provider.address1,
            "street_address_2" => provider.address2,
          },
        }
      end

      before do
        get :show, params: {
          recruitment_cycle_year: recruitment_cycle_year,
          code: provider_code,
        }
      end

      it { expect(response).to have_http_status(:success) }

      it "returns the correct attributes for the provider" do
        expect(json_response["data"]).to include(expected_data)
      end

      context "with lowercase provider code" do
        let(:provider_code) { provider.provider_code.downcase }

        it { expect(response).to have_http_status(:success) }

        it "returns the correct attributes for the provider" do
          expect(json_response["data"]).to include(expected_data)
        end
      end
    end
  end
end