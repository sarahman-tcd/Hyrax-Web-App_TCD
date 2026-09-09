class ChangeBulkraxTextColumnsToLongText < ActiveRecord::Migration[5.1]
  def up
    change_column :bulkrax_entries, :raw_metadata, :text, limit: 4294967295
    change_column :bulkrax_entries, :parsed_metadata, :text, limit: 4294967295
    change_column :bulkrax_entries, :last_error, :text, limit: 4294967295
    
    change_column :bulkrax_importers, :last_error, :text, limit: 4294967295
  end

  def down
    change_column :bulkrax_entries, :raw_metadata, :text, limit: 65535
    change_column :bulkrax_entries, :parsed_metadata, :text, limit: 65535
    change_column :bulkrax_entries, :last_error, :text, limit: 65535
    
    change_column :bulkrax_importers, :last_error, :text, limit: 65535
  end
end
