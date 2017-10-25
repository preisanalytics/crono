require 'active_record'

module Crono
  # Crono::CronoJob is a ActiveRecord model to store job state
  class CronoJob < ActiveRecord::Base
    self.table_name = 'crono_jobs'

    serialize :period, Crono::Period

    def self.all_past
      where('next_perform_at <= ?', Time.now).where('pause IS FALSE AND maintenance_pause IS FALSE').all
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

    def perform_locked(mutex)
      Thread.new do
        mutex.synchronize do 
          self.with_lock do 
            #check if it still should run
            if next_perform_at <= Time.now
              scheduled_execution_time = next_perform_at
              self.last_performed_at = Time.now
              self.next_perform_at = period.next(since: last_performed_at)
              perform_job(scheduled_execution_time)
            end
          end
        end
      end
    end

    private

    def perform_job(scheduled_execution_time)
      args = self.args.first.stringify_keys
      args["arguments"]["scheduled_execution_time"] = next_perform_at
      performer.constantize.new.perform(args)
      handle_job_success
    rescue StandardError => e
      handle_job_fail(e)
    ensure
      save
    end

    def handle_job_fail(exception)
      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = false
      Rails.logger.error "Finished #{performer} in #{finished_time_sec} seconds"\
                " with error: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      CommerceUp.metric.error("crono_count_not_perform", message: "exception during shedule execution", crono_job_id: self.id) if CommerceUp
    end

    def handle_job_success
      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = true
      Rails.logger.info "Finished #{performer} in #{finished_time_sec} seconds"
    end

  end
end
