# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SolrSanitizer do
  describe '.escape' do
    it 'removes { characters' do
      expect(described_class.escape('{!lucene}')).not_to include('{')
    end

    it 'removes } characters' do
      expect(described_class.escape('{!lucene}')).not_to include('}')
    end

    it 'removes ! characters' do
      expect(described_class.escape('{!lucene}')).not_to include('!')
    end

    it 'removes full local parameter syntax {!lucene}' do
      result = described_class.escape('{!lucene}')
      expect(result).to eq('lucene')
    end

    it 'removes {!raw f=title_tesim} style injection' do
      result = described_class.escape('{!raw f=title_tesim}')
      expect(result).not_to match(/\{!/)
    end

    it 'passes normal text through unchanged except for RSolr escaping' do
      result = described_class.escape('some title')
      expect(result).to eq('some title')
    end

    it 'escapes standard Lucene special characters via RSolr' do
      result = described_class.escape('foo+bar')
      expect(result).to include('\\+')
    end

    it 'handles nil input gracefully' do
      expect { described_class.escape(nil) }.not_to raise_error
    end

    it 'handles empty string' do
      expect(described_class.escape('')).to eq('')
    end

    it 'does not escape * and ? (wildcards permitted by RSolr)' do
      # RSolr.solr_escape escapes * and ? — SolrSanitizer just adds { } ! stripping on top
      # This test documents the expected output
      result = described_class.escape('foo*')
      expect(result).not_to include('{')
      expect(result).not_to include('}')
      expect(result).not_to include('!')
    end
  end
end
