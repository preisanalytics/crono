class CreateCronoJobs < ActiveRecord::Migration[4.2]
  def self.up
    create_table :crono_jobs do |t|
      t.text      :name
      t.string    :performer, null: false
      t.jsonb     :period, null: false
      t.jsonb     :args
      t.datetime  :next_perform_at
      t.datetime  :last_performed_at
      t.boolean   :healthy
      t.text      :log
      t.timestamps null: false
      t.timestamp   :paused_at
      t.timestamp   :maintenance_paused_at
    end
  end

  def self.down
    drop_table :crono_jobs
  end
end
