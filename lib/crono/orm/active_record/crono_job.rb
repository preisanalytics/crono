require 'active_record'

module Crono
  # Crono::CronoJob is a ActiveRecord model to store job state
  class CronoJob < ActiveRecord::Base
    self.table_name = 'crono_jobs'
    attr_accessor :job_log, :job_logger

    serialize :period, Crono::Period

    before_save :calculate_next_perform
    before_create :calculate_next_perform

    def initialize(*args)
      self.job_log = StringIO.new
      self.job_logger = Logger.new(job_log)
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
              self.last_performed_at = Time.now
              self.next_perform_at = period.next(since: last_performed_at)
              perform_job
            end
          end
        end
      end
    end


    def save
      self.transaction do
        super
        saved_log = self.reload.log || ''
        self.log = saved_log + job_log.string if job_log
        super
        clear_job_log
      end
    end

    private

    def perform_job
      performer.constantize.new.perform *args
    rescue StandardError => e
      handle_job_fail(e)
    else
      handle_job_success
    ensure
      save
    end

    def clear_job_log
      job_log.truncate(job_log.rewind)
    end

    def handle_job_fail(exception)
      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = false
      log_error "Finished #{performer} in #{finished_time_sec} seconds"\
                " with error: #{exception.message}"
      log_error exception.backtrace.join("\n")
    end

    def handle_job_success
      finished_time_sec = format('%.2f', Time.now - last_performed_at)
      self.healthy = true
      log_message "Finished #{performer} in #{finished_time_sec} seconds"
    end

    def log_error(message)
      log_message(message, Logger::ERROR)
    end

    def log_message(message, severity = Logger::INFO)
      logger.log severity, message
      job_logger.log severity, message
    end

  end
end
