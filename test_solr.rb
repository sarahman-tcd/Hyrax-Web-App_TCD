begin
  require './config/environment'
  work = Folio.new
  work.title = ["Test"]
  work.abstract = ["A" * 30_000 + "X"]
  
  solr_doc = work.to_solr
  puts "=== AFTER MOCKING 30,001 BYTES ==="
  puts "abstract_truncated_bsi: #{solr_doc['abstract_truncated_bsi'].inspect}"
  puts "abstract_tesim length: #{solr_doc['abstract_tesim']&.map(&:bytesize)}"
rescue => e
  puts e.message
end
