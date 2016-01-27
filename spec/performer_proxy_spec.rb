require 'spec_helper'

describe Crono::PerformerProxy do
  it 'should add job to schedule' do
    expect(Crono.scheduler).to receive(:add_job).with(kind_of(Crono::CronoJob))
    Crono.perform(TestJob).every(2.days, at: '15:30')
  end

  it 'should add job with args to schedule' do
    expect(Crono::CronoJob).to receive(:create).with(performer: TestJob, period: kind_of(Crono::Period), args: [:some, {some: 'data'}])
    allow(Crono.scheduler).to receive(:add_job)
    Crono.perform(TestJob, :some, {some: 'data'}).every(2.days, at: '15:30')
  end
end
