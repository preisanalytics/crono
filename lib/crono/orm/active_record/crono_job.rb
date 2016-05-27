require 'active_record'

module Crono
  # Crono::CronoJob is a ActiveRecord model to store job state
  class CronoJob < ActiveRecord::Base
    self.table_name = 'crono_jobs'
    attr_accessor :job_log, :job_logger

    serialize :period, Crono::Period

    def self.all_past
      where('next_perform_at <= ?', Time.now).where('pause IS FALSE AND maintenance_pause IS FALSE').all
    end

    before_save :calculate_next_perform
    before_create :calculate_next_perform

    def initialize(*args)
      self.job_log = StringIO.new
      self.job_logger ||= Rails.logger
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
        super
        saved_log = self.reload.log || ''
        self.log = saved_log + job_log.string if job_log
        super
        clear_job_log if job_log
    end

    private

    def perform_job
      logger = Logger.new(File.join(Rails.root, 'log', 'crono_output.log'))
      logger.info "perform job"
      logger.info performer
      logger.info args
      performer.constantize.new.perform *args
      logger.info "performed_job"
    rescue StandardError => e
      logger.info "cachted error"
      logger.info e
      logger.info e.backtrace.join("\n")
      handle_job_fail(e)
    else
      logger.info "perform succesed"
      handle_job_success
    ensure
      logger.info "perform ensure"
      save
      logger.info "perform ensure2"
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
      CommerceUp.metric.error("crono_count_not_perform", message: "exception during shedule execution", crono_job_id: self.id) if CommerceUp
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
      stdout_logger = Logger.new(STDOUT)
      stdout_logger.level = Logger::WARN
      stdout_logger.log severity, message
      logger.log severity, message
      self.job_logger ||= Rails.logger
      self.job_logger.log severity, message
    end

  end
end
