# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Projects::ReportsController, type: :controller do
  let!(:platform) { create(:platform) }
  let!(:another_platform) { create(:platform) }

  let(:user) { create(:user, platform: platform) }
  let(:another_platform_user) { create(:user, platform: another_platform) }

  let(:current_user) { user }
  let(:token_role) { 'scoped_user' }
  let(:platform_token) { platform.token }
  let(:user_id) { current_user.id }

  before do
    allow(controller).to receive(:decoded_api) do
      { user_id: user_id,
        role: token_role,
        platform_token: platform_token }.stringify_keys
    end
  end

  describe 'POST #create' do
    let(:project) { create(:project, user_id: current_user.id, platform: platform) }
    let(:report) { build(:report, project: project, user: user) }

    subject { response }

    context 'with anonymous' do
      before do
        allow(controller).to receive(:decoded_api).and_return(nil)
        allow(controller).to receive(:platform_token).and_return(platform.token)

        post :create, params: { project_id: report.project_id, report: report.attributes.compact["data"] }
      end

      it { is_expected.to have_http_status('403') }
    end

    context 'with platform_user from another platform' do
      let(:platform_token) { another_platform.token }
      let(:user_id) { nil }
      let(:token_role) { 'platform_user' }

      it do
        expect {
          post :create, params: { project_id: report.project_id, report: report.attributes.compact }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with platform_user from current_platform' do
      let(:token_role) { 'platform_user' }
      let(:user_id) { nil }
      let(:report_params) { report.attributes.compact }

      before do
        post :create, params: { project_id: report.project_id, report: report_params }
      end

      it { is_expected.to have_http_status('200') }
      it 'should create a new report' do
        json = JSON.parse(response.body)
        expect(CommonModels::Report.find(json['report_id']).present?).to eq(true)
      end
    end
  end
end
