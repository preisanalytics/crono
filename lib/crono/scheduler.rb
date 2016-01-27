module Crono
  # Scheduler is a container for job list and queue
  class Scheduler
    attr_accessor :jobs

    def initialize
      self.jobs = []
    end

    def clear
      self.jobs = []
    end

    def add_job(job)
      jobs << job
    end

    def next_jobs
      jobs.group_by(&:next_perform_at).sort_by {|time,_| time }.first
    end
  end

  mattr_accessor :scheduler
end
