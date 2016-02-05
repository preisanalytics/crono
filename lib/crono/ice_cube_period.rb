require 'ice_cube'

module Crono
  class IceCubePeriod

    attr_accessor :schedule

    def self.from_h(ice_cube_hash)
      period = new
      period.schedule = IceCube::Schedule.from_hash(ice_cube_hash)
      period
    end

    def self.from_ice_cube_schedule(schedule)
      period = new
      period.schedule = schedule
      period
    end

    def next(since: Time.now)
      self.schedule.next_occurrence(since).to_time
    end

    def to_h
      {type: 'ice_cube', ice_cube: schedule.to_hash}
    end
  end
end