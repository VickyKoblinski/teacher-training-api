require 'rails_helper'

RSpec.describe Api::V1::CoursesController, type: :controller do
  describe "index" do
    it "render service unavailable" do
      allow(controller).to receive(:index).and_raise(PG::ConnectionBad)
      allow(controller).to receive(:authenticate)

      get :index
      expect(response).to have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json). to eq(
        'code' => 503, 'status' => 'Service Unavailable'
      )
    end
  end
end