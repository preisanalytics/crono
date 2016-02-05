require 'bundler/setup'
Bundler.setup

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'timecop'
require 'byebug'
require 'chronic'
require 'ice_cube'
require 'crono'
require 'generators/crono/install/templates/migrations/create_crono_jobs.rb'
require 'pg'


conn = PG.connect(dbname: 'postgres')
conn.exec 'DROP DATABASE IF EXISTS crono_test'
conn.exec 'CREATE DATABASE crono_test'
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  database: 'crono_test'
)

ActiveRecord::Base.logger = Logger.new(STDOUT)
CreateCronoJobs.up

class TestJob
  def perform
  end
end

class TestFailingJob
  def perform
    fail 'Some error'
  end
end
