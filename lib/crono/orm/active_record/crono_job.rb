require 'active_record'

module Crono
  # Crono::CronoJob is a ActiveRecord model to store job state
  class CronoJob < ActiveRecord::Base
    self.table_name = 'crono_jobs'

    serialize :period, Crono::Period

    def self.all_past
      where('next_perform_at <= ?', Time.now).where('paused_at IS NULL AND maintenance_paused_at IS NULL AND next_perform_at IS NOT NULL').order(:next_perform_at)
    end

    before_save :calculate_next_perform
    before_create :calculate_next_perform

    def initialize(*args)
      super *args
    end

    def calculate_next_perform
      base_time = Time.now
      base_time = last_performed_at if last_performed_at
      self.next_perform_at = period.next(since: base_time)
    end

    def self.outdated
      self
    end


    def perform
      scheduled_execution_time = next_perform_at
      self.last_performed_at = Time.now
      self.next_perform_at = period.next(since: last_performed_at)
      perform_job(scheduled_execution_time)
    end

    def performer_instance
      performer.constantize.new
    end

    private

    def perform_job(scheduled_execution_time)
      current_args = self.args.deep_dup.stringify_keys
      current_args["arguments"] ||={}
      current_args["arguments"]["scheduled_execution_time"] = scheduled_execution_time
      current_args["arguments"]["crono_job"] = self
      performer_instance.perform(current_args)
      handle_job_success
    rescue StandardError => e
      handle_job_fail(e)
    ensure
      save
    end

    def handle_job_fail(exception)
#      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = false
    end

    def handle_job_success
#      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = true
    end
  end
end
