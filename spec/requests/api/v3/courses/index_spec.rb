require "rails_helper"

describe "GET v3/recruitment_cycle/:recruitment_cycle_year/courses" do
  let(:current_cycle) { create(:recruitment_cycle) }
  let(:findable_status) { build(:site_status, :findable) }

  describe "funding filter" do
    let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses?filter[funding]=salary" }

    context "with a salaried course" do
      let(:course_with_salary) { create(:course, :with_salary, site_statuses: [findable_status]) }

      before do
        course_with_salary
      end

      it "is returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(1)
      end
    end

    context "with a non-salaried course" do
      let(:non_salary_course) { create(:course, site_statuses: [findable_status]) }

      before do
        non_salary_course
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes).to be_empty
      end
    end
  end

  describe "qualifications filter" do
    let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses?filter[qualification]=pgce" }

    context "with a pgce qualification" do
      let(:course_with_pgce) { create(:course, :resulting_in_pgce, site_statuses: [findable_status]) }

      before do
        course_with_pgce
      end

      it "is returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(1)
      end
    end

    context "without a pgce qualification" do
      let(:course_without_pgce) { create(:course, site_statuses: [findable_status]) }

      before do
        course_without_pgce
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(0)
      end
    end
  end

  describe "vacancies filter" do
    let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses?filter[has_vacancies]=true" }

    context "with a course with vacancies" do
      let(:findable_status_with_vacancies) { build(:site_status, :findable, :with_any_vacancy) }
      let(:course_with_vacancies) { create(:course, site_statuses: [findable_status_with_vacancies]) }

      before do
        course_with_vacancies
      end

      it "is returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(1)
      end
    end

    context "with a course with no vacancies" do
      let(:findable_status_with_no_vacancies) { build(:site_status, :findable, :with_no_vacancies) }
      let(:course_without_vacancies) { create(:course, site_statuses: [findable_status_with_no_vacancies]) }

      before do
        course_without_vacancies
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(0)
      end
    end
  end

  describe "study type filter" do
    let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses?filter[study_type]=full_time" }

    context "with a full time course" do
      let(:full_time_course) { create(:course, study_mode: :full_time, site_statuses: [findable_status]) }

      before do
        full_time_course
      end

      it "is returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(1)
      end
    end

    context "with a part time course" do
      let(:part_time_course) { create(:course, study_mode: :part_time) }

      before do
        part_time_course
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(0)
      end
    end
  end

  describe "recruitment_cycle scoping" do
    context "course not in the provided recruitment cycle" do
      let(:provider) { create(:provider, :next_recruitment_cycle) }
      let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses" }

      let(:course_in_next_cycle) { create(:course, provider: provider, site_statuses: [findable_status]) }

      before do
        course_in_next_cycle
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(0)
      end
    end
  end

  describe "findable scoping" do
    context "course is not findable" do
      let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses" }
      let(:not_findable_course) { create(:course) }

      before do
        not_findable_course
      end

      it "is not returned" do
        get request_path
        json_response = JSON.parse(response.body)
        course_hashes = json_response["data"]
        expect(course_hashes.count).to eq(0)
      end
    end
  end

  describe "pagination" do
    let(:request_path) { "/api/v3/recruitment_cycles/#{current_cycle.year}/courses" }

    it "paginates the results" do
      get request_path
      headers = response.headers

      expect(headers["Per-Page"]).to be_present
      expect(headers["Total"]).to be_present
    end
  end
end
