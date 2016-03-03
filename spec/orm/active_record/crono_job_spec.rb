require 'spec_helper'

describe Crono::CronoJob do

  let(:period) { Crono::Period.new(2.day, at: '15:00') }
  let(:args) {[{some: 'data'}]}
  let(:job) { Crono::CronoJob.create(performer: TestJob, period: period, args: []) }
  let(:job_with_args) { Crono::CronoJob.create(performer: TestJob, period: period, args: args) }
  let(:failing_job) { Crono::CronoJob.create(performer: TestFailingJob, period: period, args: []) }

  it 'should contain performer and period' do
    expect(job.performer).to eq "TestJob"
    expect(job.period.to_h).to eq period.to_h
  end

  it 'should contain data as JSON String' do
    expect(job_with_args.args).to eq [{"some" => "data"}]
  end

  describe '.all_past' do
    let(:period) { Crono::Period.new(20.minutes) }
    let!(:past_job) { Crono::CronoJob.create(performer: TestJob, period: period, args: []) }
    let!(:past_job_paused) { Crono::CronoJob.create(performer: TestJob, period: period, args: [], pause: true) }
    let!(:past_job_maintainenc_pause) { Crono::CronoJob.create(performer: TestJob, period: period, args: [], maintenance_pause: true) }

    it 'returns all past' do
      Timecop.freeze(Date.today + 2.days) do
        expect(Crono::CronoJob.all_past.count > 0).to eq true
        Crono::CronoJob.all_past.each do |job|
          expect(job.next_perform_at < Time.now).to eq true
        end
      end
    end

    it 'returns all not stoped by pause field' do
      Timecop.freeze(Date.today + 2.days) do
        expect(Crono::CronoJob.all_past.count > 0).to eq true
        Crono::CronoJob.all_past.each do |job|
          expect(job.maintenance_pause).not_to eq true
        end
      end
    end

    it 'returns all not stoped by maintaince_pause field' do
      Timecop.freeze(Date.today + 2.days) do
        expect(Crono::CronoJob.all_past.count > 0).to eq true
        Crono::CronoJob.all_past.each do |job|
          expect(job.pause).not_to eq true
        end
      end
    end
  end

  describe '#save' do

    it 'should update saved job' do
      job.last_performed_at = Time.now
      job.healthy = true
      job.args = [{some: 'data'}]
      job.save
      @crono_job = Crono::CronoJob.find_by(id: job.id)
      expect(@crono_job.last_performed_at.utc.to_s).to be_eql job.last_performed_at.utc.to_s
      expect(@crono_job.healthy).to be true

      expect(@crono_job.args).to eq [{"some" => "data"}]
      expect(@crono_job.next_perform_at).to eq period.next(since: job.last_performed_at)
      expect(@crono_job.period.to_h).to eq ({iteration: "2.days" ,at:"15:0",on:nil})
    end

    it 'should save and truncate job log_message' do
      message = 'test message'
      job.send(:log_message, message)
      job.save
      expect(job.reload.log).to include message
      expect(job.job_log.string).to be_empty
    end
  end

  describe '#log_message' do
    it 'should write log messages to both common and job log' do
      message = 'Test message'
      expect(job.logger).to receive(:log).with(Logger::INFO, message)
      expect(job.job_logger).to receive(:log).with(Logger::INFO, message)
      job.send(:log_message, message)
    end

    it 'should write job log to Job#job_log' do
      message = 'Test message'
      job.send(:log_message, message)
      expect(job.job_log.string).to include(message)
    end
  end

  describe '#log_error' do
    it 'should call log with ERROR severity' do
      message = 'Test message'
      expect(job).to receive(:log_message).with(message, Logger::ERROR)
      job.send(:log_error, message)
    end
  end
end
