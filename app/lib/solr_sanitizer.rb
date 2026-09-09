# frozen_string_literal: true

# SolrSanitizer provides a single canonical method for sanitising user-supplied
# strings before they are interpolated into Solr query strings.
#
# It combines:
#   1. RSolr.solr_escape  – escapes all standard Lucene special characters
#                           (+ - && || ! ( ) { } [ ] ^ " ~ * ? : \ /)
#   2. An additional strip of { } and ! characters, which are the building
#      blocks of Solr Local Parameter syntax (e.g. {!lucene}, {!raw f=…}).
#      Even if a future version of RSolr stops escaping these, injection is
#      still blocked.
#
# Usage:
#   safe = SolrSanitizer.escape(params[:term])
#   q: "title_tesim:*#{safe}*"
module SolrSanitizer
  # Characters that form Solr Local Parameter syntax and must be removed even
  # after RSolr escaping.
  LOCAL_PARAM_CHARS = /[\{\}!]/.freeze

  # Escapes *input* so it is safe to interpolate into a Solr query string.
  #
  # @param input [String, nil] raw user input
  # @return [String] sanitised string, safe for Solr query interpolation
  def self.escape(input)
    raw = input.to_s
    # Step 1: standard Lucene escaping via RSolr
    escaped = RSolr.solr_escape(raw)
    # Step 2: strip any remaining local-parameter characters ({, }, !)
    escaped.gsub(LOCAL_PARAM_CHARS, '')
  end
end
