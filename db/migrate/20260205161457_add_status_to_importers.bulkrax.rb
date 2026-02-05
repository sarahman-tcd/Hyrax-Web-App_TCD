# This migration comes from bulkrax (originally 20200301232856)
class AddStatusToImporters < ActiveRecord::Migration[5.1]
  def change
    add_column :bulkrax_importers, :last_error, :text
    add_column :bulkrax_importers, :last_error_at, :datetime
    add_column :bulkrax_importers, :last_succeeded_at, :datetime
  end
end
