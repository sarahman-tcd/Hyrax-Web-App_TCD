# This migration comes from bulkrax (originally 20190325183136)
class CreateBulkraxEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :bulkrax_entries do |t|
      t.string :identifier
      t.string :collection_id
      t.string :type
      t.references :importer, foreign_key: {to_table: :bulkrax_importers}
      t.text :raw_metadata
      t.text :parsed_metadata

      t.timestamps
    end
  end
end
