require 'stringio'
require 'logger'

module Crono
  # Crono::Job represents a Crono job
  class Job
    include Logging

    def self.load_all
      Crono::CronoJob.all.map do |model|
        new(model)
      end
    end

    def self.create(performer, period, job_args)
      model = Crono::CronoJob.create_with(performer: performer.to_s, period: JSON.generate(period.to_h), args: JSON.generate(job_args), next_perform_at: period.next)
        .find_or_create_by(job_id: job_id(performer, period, job_args))
      new(model)
    end

    def self.job_id(performer, period, job_args)
      "Perform #{performer} #{period.description} with #{JSON.generate(job_args)}"
    end

    attr_accessor :model, :job_log, :job_logger, :execution_interval

    def initialize(model)
      self.execution_interval = 0.minutes
      self.model = model
      self.job_log = StringIO.new
      self.job_logger = Logger.new(job_log)
      @semaphore = Mutex.new
    end

    def performer
      model.performer.constantize
    end

    def period
      Period.from_h JSON.parse(model.period)
    end

    def job_args
      JSON.parse(model.args)
    end

    def job_args=(args)
      model.args = JSON.generate(args)
    end

    def last_performed_at
      model.last_performed_at
    end

    def last_performed_at=(last_performed_at)
      model.last_performed_at = last_performed_at
    end

    def next_perform_at
      model.next_perform_at
    end

    def next_perform_at=(next_perform_at)
      model.next_perform_at = next_perform_at
    end

    def healthy
      model.healthy
    end

    def healthy=(healthy)
      model.healthy = healthy
    end

    def next
      return next_perform_at if next_perform_at.future?
      Time.now
    end

    def description
      job_id
    end

    def job_id
      model.job_id
    end

    def perform
      return Thread.new {} if perform_before_interval?

      log "Perform #{performer}"
      self.last_performed_at = Time.now
      self.next_perform_at = period.next(since: last_performed_at)

      Thread.new { perform_job }
    end

    def save
      @semaphore.synchronize do
        update_model
        clear_job_log
        ActiveRecord::Base.clear_active_connections!
      end
    end

    private

    def clear_job_log
      job_log.truncate(job_log.rewind)
    end

    def update_model
      model.transaction do
        model.save
        saved_log = model.reload.log || ''
        model.log = saved_log + job_log.string
        model.save
      end
    end

    def perform_job
      performer.new.perform *job_args
    rescue StandardError => e
      handle_job_fail(e)
    else
      handle_job_success
    ensure
      save
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
      log "Finished #{performer} in #{finished_time_sec} seconds"
    end

    def log_error(message)
      log(message, Logger::ERROR)
    end

    def log(message, severity = Logger::INFO)
      @semaphore.synchronize do
        logger.log severity, message
        job_logger.log severity, message
      end
    end

    def perform_before_interval?
      return false if execution_interval == 0.minutes

      return true if self.last_performed_at.present? && self.last_performed_at > execution_interval.ago
      return true if model.updated_at.present? && model.created_at != model.updated_at && model.updated_at > execution_interval.ago

      Crono::CronoJob.transaction do
        job_record = Crono::CronoJob.where(job_id: job_id).lock(true).first

        return true if  job_record.updated_at.present? &&
          job_record.updated_at != job_record.created_at &&
          job_record.updated_at > execution_interval.ago

        job_record.touch

        return true unless job_record.save
      end

      # Means that this node is permit to perform the job.
      return false
    end
  end
end
