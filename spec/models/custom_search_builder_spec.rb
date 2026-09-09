# frozen_string_literal: true
require 'rails_helper'

RSpec.describe CustomSearchBuilder do
  # Build a minimal stub context that CustomSearchBuilder requires
  let(:blacklight_config) { Blacklight::Configuration.new }
  let(:scope) do
    double('scope',
           blacklight_config: blacklight_config,
           current_user: nil,
           current_ability: nil)
  end

  def builder_for(params)
    described_class.new(scope).with(params)
  end

  describe '#add_custom_filters' do
    context 'with a normal query' do
      it 'builds a valid contains query' do
        params = {
          search_field:    ['title'],
          search_operator: ['contains'],
          search_query:    ['history'],
          search_logic:    []
        }
        solr_params = {}
        builder_for(params).add_custom_filters(solr_params)
        expect(solr_params[:q]).to include('title_tesim')
        expect(solr_params[:q]).to include('history')
      end
    end

    context 'with Solr Local Parameter injection {!lucene} in the query value' do
      it 'strips local parameter syntax before building the Solr query' do
        params = {
          search_field:    ['title'],
          search_operator: ['contains'],
          search_query:    ['{!lucene}malicious'],
          search_logic:    []
        }
        solr_params = {}
        builder_for(params).add_custom_filters(solr_params)

        expect(solr_params[:q]).not_to match(/\{!/)
        expect(solr_params[:q]).not_to include('{')
        expect(solr_params[:q]).not_to include('!')
      end

      it 'strips {!raw f=id} style injection' do
        params = {
          search_field:    ['creator'],
          search_operator: ['equals'],
          search_query:    ['{!raw f=id}abc'],
          search_logic:    []
        }
        solr_params = {}
        builder_for(params).add_custom_filters(solr_params)

        expect(solr_params[:q]).not_to match(/\{!/)
      end
    end

    context 'with an unlisted field (whitelist enforcement)' do
      it 'skips the row and returns *:* when no valid rows remain' do
        params = {
          search_field:    ['nonexistent_field'],
          search_operator: ['contains'],
          search_query:    ['test'],
          search_logic:    []
        }
        solr_params = {}
        builder_for(params).add_custom_filters(solr_params)

        expect(solr_params[:q]).to eq('*:*')
      end
    end

    context 'with an unlisted operator (whitelist enforcement)' do
      it 'skips the row and returns *:* when no valid rows remain' do
        params = {
          search_field:    ['title'],
          search_operator: ['not_an_operator'],
          search_query:    ['test'],
          search_logic:    []
        }
        solr_params = {}
        builder_for(params).add_custom_filters(solr_params)

        expect(solr_params[:q]).to eq('*:*')
      end
    end
  end
end
