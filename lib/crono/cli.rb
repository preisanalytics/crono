require 'crono'
require 'optparse'

module Crono
  # Crono::CLI - The main class for the crono daemon exacutable `bin/crono`
  class CLI
    include Singleton

    COMMANDS = %w(start stop restart run zap reload status)

    attr_accessor :config

    def initialize
      Crono.scheduler = Scheduler.new
    end

    def run
      load_rails
      load_jobs_from_db
      print_banner

      check_jobs
      start_updating_working_loop
    end

    private

    def print_banner
      Rails.logger.info "Loading Crono #{Crono::VERSION}"
      Rails.logger.info "Running in #{RUBY_DESCRIPTION}"

      Rails.logger.info 'Jobs:'
      Crono.scheduler.jobs.each do |job|
        Rails.logger.info "'#{job.performer}' with rule '#{job.period.description}'"\
                    " next time will perform at #{job.next_perform_at}"
      end
    end

    def load_rails
      require 'rails'
      require File.expand_path('config/environment.rb')
    end

    def load_jobs_from_db
      Crono.scheduler.clear
      Crono::CronoJob.all.each do |job|
        Crono.scheduler.add_job(job)
      end
    end

    def check_jobs
      return if Crono.scheduler.jobs.present?
      Rails.logger.error "You have no jobs"
    end

    def root
      @root ||= rails_root_defined? ? ::Rails.root : DIR_PWD
    end

    def rails_root_defined?
      defined?(::Rails.root)
    end

    def start_updating_working_loop
      @mutex = Mutex.new
      loop do
        Crono::CronoJob.all_past.each do |job|
          job.perform_locked @mutex
        end
        sleep(10) 
      end
    end

  end
end
