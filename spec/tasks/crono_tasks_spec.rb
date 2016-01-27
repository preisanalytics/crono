require 'spec_helper'
require 'rake'

load 'tasks/crono_tasks.rake'
Rake::Task.define_task(:environment)

describe 'rake' do
  let(:period) { Crono::Period.new(2.day, at: '15:00') }

  describe 'crono:clean' do
    it 'should clean unused tasks from DB' do
      Crono::CronoJob.create!(name: 'used_job', period: period, performer: TestJob)
      ENV['CRONOTAB'] = File.expand_path('../../assets/good_cronotab.rb', __FILE__)
      Rake::Task['crono:clean'].invoke
      expect(Crono::CronoJob.where(name: 'used_job')).not_to exist
    end
  end

  describe 'crono:check' do
    it 'should check cronotab syntax' do
      ENV['CRONOTAB'] = File.expand_path('../../assets/bad_cronotab.rb', __FILE__)
      expect { Rake::Task['crono:check'].invoke }.to raise_error
    end
  end
end
