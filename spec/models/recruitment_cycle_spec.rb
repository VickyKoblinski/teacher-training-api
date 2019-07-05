# == Schema Information
#
# Table name: recruitment_cycle
#
#  id                     :bigint           not null, primary key
#  year                   :string
#  application_start_date :date
#  application_end_date   :date
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

require 'rails_helper'

describe RecruitmentCycle, type: :model do
  subject { create(:recruitment_cycle, year: "2019") }

  its(:to_s) { should eq("2019/20") }

  it "is valid with valid attributes" do
    expect(subject).to be_valid
  end

  it { is_expected.to validate_presence_of(:year) }

  describe 'associations' do
    it { should have_many(:sites) }
    it { should have_many(:courses).through(:providers) }
  end
end
