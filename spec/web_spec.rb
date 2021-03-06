require 'spec_helper'
require 'rack/test'
include Rack::Test::Methods

describe Crono::Web do
  let(:app) { Crono::Web }
  let(:period) { Crono::Period.new(2.day, at: '15:00') }

  before do
    Crono::CronoJob.destroy_all
    @test_name = 'Perform TestJob every 5 seconds'
    @test_job_log = 'All runs ok'
    @test_job = Crono::CronoJob.create!(
      period: period,
      performer: TestJob,
      name: @test_name,
      log: @test_job_log
    )
  end

  after { @test_job.destroy }

  describe '/' do
    it 'should show all jobs' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include @test_name
    end

    it 'should show a error mark when a job is unhealthy' do
      @test_job.update(healthy: false, last_performed_at: 10.minutes.ago)
      get '/'
      expect(last_response.body).to include 'Error'
    end

    it 'should show a success mark when a job is healthy' do
      @test_job.update(healthy: true, last_performed_at: 10.minutes.ago)
      get '/'
      expect(last_response.body).to include 'Success'
    end

    it 'should show a pending mark when a job is pending' do
      @test_job.update(healthy: nil)
      get '/'
      expect(last_response.body).to include 'Pending'
    end
  end

  describe '/job/:id' do
    it 'should show job log' do
      get "/job/#{@test_job.id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include @test_name
      expect(last_response.body).to include @test_job_log
    end

    it 'should show a message about the unhealthy job' do
      message = 'An error occurs during the last execution of this job'
      @test_job.update(healthy: false)
      get "/job/#{@test_job.id}"
      expect(last_response.body).to include message
    end
  end
end
