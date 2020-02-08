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
if ENV["CRONO_TEST_DB_URL"]
    uri=URI.parse(ENV["CRONO_TEST_DB_URL"])
    ar_params={ adapter: 'postgresql',
      database: uri.path[1..],
      host: uri.host,
      user: uri.user,
      password: uri.password,
      port: uri.port || 5432
    }
    pg_params={ 
      dbname: 'postgres',
      host: uri.host,
      user: uri.user,
      password: uri.password,
      port: uri.port || 5432
    }
else
  ar_params={adapter: 'postgresql',  database: 'crono_test'}
  pg_params={dbname: 'postgres'}
end  

conn = PG.connect(pg_params)
conn.exec 'DROP DATABASE IF EXISTS crono_test'
conn.exec 'CREATE DATABASE crono_test'
ActiveRecord::Base.establish_connection(ar_params)


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
