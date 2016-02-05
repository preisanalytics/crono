require 'spec_helper'

describe Crono::IceCubePeriod do
  let(:ice_cube_schedule) do 
    schedule = schedule = IceCube::Schedule.new(Time.now)
    schedule.add_recurrence_rule IceCube::Rule.daily.hour_of_day(1,3,5,7,9).minute_of_hour(0).second_of_minute(0)
    schedule
  end

  let(:ice_cube_hash) do 
    ice_cube_schedule.to_hash
  end

  describe '.from_h' do
    subject {Crono::IceCubePeriod.from_h(ice_cube_hash)}
    it 'creates the ice_cube schedule' do
      expect(subject.schedule).to be_kind_of IceCube::Schedule
    end
  end

  describe '.from_ice_cube_schedule' do
    subject {Crono::IceCubePeriod.from_ice_cube_schedule(ice_cube_schedule)}
    it 'creates the ice_cube schedule' do
      expect(subject.schedule).to be_kind_of IceCube::Schedule
    end
  end

  describe '#next' do
    subject {Crono::IceCubePeriod.from_h(ice_cube_hash)}

    it 'returns the next after now unless a time is given' do
      Timecop.freeze(Time.now.beginning_of_day) do
        expect(subject.next).to be_eql(Time.now.beginning_of_hour + 1.hour)
      end
    end

    it 'returns the next after a given time' do
      Timecop.freeze(Time.now.beginning_of_day) do
        expect(subject.next(since: Time.now + 2.hour)).to be_eql(Time.now.beginning_of_hour + 3.hour)
      end
    end
  end

  describe '#to_h' do

    subject {Crono::IceCubePeriod.from_h(ice_cube_hash)}
    it 'returns the same hash' do
      expected = {type: 'ice_cube', ice_cube: ice_cube_hash}
      expect(subject.to_h).to eq(expected)
    end
  end
end
