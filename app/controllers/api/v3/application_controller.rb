module API
  module V3
    class ApplicationController < ActionController::API
      include Pagy::Backend

      rescue_from ActiveRecord::RecordNotFound, with: :jsonapi_404

      before_action :store_request_id

      def jsonapi_404
        render jsonapi: nil, status: :not_found
      end

    private

      def paginate(scope)
        _pagy, paginated_records = pagy(scope, items: per_page, page: page)

        paginated_records
      end

      def per_page
        params[:page] ||= {}

        [(params.dig(:page, :per_page) || default_per_page).to_i, max_per_page].min
      end

      def default_per_page
        100
      end

      def max_per_page
        100
      end

      def page
        params[:page] ||= {}
        (params.dig(:page, :page) || 1).to_i
      end

      def build_recruitment_cycle
        @recruitment_cycle = RecruitmentCycle.find_by(
          year: params[:recruitment_cycle_year],
        ) || RecruitmentCycle.current_recruitment_cycle
      end

      def fields_param
        params.fetch(:fields, {})
          .permit(:subject_areas, :subjects, :courses, :providers)
          .to_h
          .map { |k, v| [k, v.split(",").map(&:to_sym)] }
      end

      def store_request_id
        RequestStore.store[:request_id] = request.uuid
      end
    end
  end
end
