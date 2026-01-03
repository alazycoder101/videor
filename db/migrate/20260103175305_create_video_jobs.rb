class CreateVideoJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :video_jobs do |t|
      t.string :client_id, null: false
      t.string :audio_key, null: false
      t.string :image_key, null: false
      t.string :output_key
      t.integer :status, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :video_jobs, :client_id
  end
end
