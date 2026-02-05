# This migration comes from bulkrax (originally 20190715162044)
class ChangeCollectionIdsOnEntries < ActiveRecord::Migration[5.1]
  def change
    rename_column :bulkrax_entries, :collection_id, :collection_ids
  end
end
