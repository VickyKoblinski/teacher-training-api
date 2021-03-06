module API
  module V2
    class AccessRequestsController < API::V2::ApplicationController
      deserializable_resource :access_request,
                              only: %i[create],
                              class: API::V2::DeserializableAccessRequest

      before_action :build_access_request, only: :approve

      def approve
        result = AccessRequestApprovalService.call(@access_request)

        render status: :ok, json: { result: result }
      end

      def show
        authorize AccessRequest
        @access_request = AccessRequest.find(params[:id])

        if @access_request.discarded?
          render jsonapi: nil, status: :not_found
        else
          render jsonapi: @access_request, include: params[:include]
        end
      end

      def index
        authorize AccessRequest
        @access_requests = AccessRequest.requested.includes(:requester).by_request_date

        render jsonapi: @access_requests, include: params[:include]
      end

      def create
        authorize AccessRequest
        @access_request = AccessRequest.new(access_request_params)
        @access_request.add_additonal_attributes(@access_request.requester_email)

        if @access_request.valid?
          render jsonapi: @access_request
        else
          render jsonapi_errors: @access_request.errors, status: :unprocessable_entity
        end
      end

      def destroy
        authorize AccessRequest
        @access_request = AccessRequest.find(params[:id])
        @access_request.discard
      end

    private

      def build_access_request
        @access_request = authorize AccessRequest.requested.find(params[:id])
      end

      def access_request_params
        params.require(:access_request).permit(
          :email_address,
          :first_name,
          :last_name,
          :organisation,
          :reason,
          :requester_email,
        ).with_defaults requester_email: current_user.email
      end
    end
  end
end
