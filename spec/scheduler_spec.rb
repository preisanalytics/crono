require 'spec_helper'

describe Crono::Scheduler do
  let(:scheduler) { Crono::Scheduler.new }

  describe '#next_jobs' do
    it 'should return next job in schedule' do
      scheduler.jobs = jobs = [
        Crono::Period.new(3.days, at: 10.minutes.from_now.strftime('%H:%M')),
        Crono::Period.new(1.day, at: 20.minutes.from_now.strftime('%H:%M')),
        Crono::Period.new(7.days, at: 40.minutes.from_now.strftime('%H:%M'))
      ].map { |period| Crono::CronoJob.create(performer: TestJob, period: period, args: []) }

      time, jobs = scheduler.next_jobs
      expect(jobs).to be_eql [jobs[0]]
    end

    it 'should return an array of jobs scheduled at same time with `at`' do
      time = 5.minutes.from_now
      scheduler.jobs = jobs = [
        Crono::Period.new(1.day, at: time.strftime('%H:%M')),
        Crono::Period.new(1.day, at: time.strftime('%H:%M')),
        Crono::Period.new(1.day, at: 10.minutes.from_now.strftime('%H:%M'))
      ].map { |period| Crono::CronoJob.create(performer: TestJob, period: period, args: []) }

      time, jobs = scheduler.next_jobs
      expect(jobs).to be_eql [jobs[0], jobs[1]]
    end

    it 'should handle a few jobs scheduled at same time without `at`' do
      TestJob2 = TestJob
      scheduler.jobs = jobs = [
        Crono::CronoJob.create(performer: TestJob, period: Crono::Period.new(10.seconds), args: []),
        Crono::CronoJob.create(performer: TestJob2, period: Crono::Period.new(10.seconds), args: []),
        Crono::CronoJob.create(performer: TestJob, period: Crono::Period.new(1.day, at: 10.minutes.from_now.strftime('%H:%M')), args: [])
      ]

      _, next_jobs = scheduler.next_jobs
      expect(next_jobs).to eq [jobs[0]]

      Timecop.travel(4.seconds.from_now)
      jobs[1].perform

      _, next_jobs = scheduler.next_jobs
      expect(next_jobs).to eq [jobs[0]]
    end
  end
end
