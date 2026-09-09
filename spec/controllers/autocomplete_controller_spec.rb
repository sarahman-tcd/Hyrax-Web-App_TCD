# frozen_string_literal: true
require 'rails_helper'

RSpec.describe AutocompleteController, type: :controller do
  describe 'GET #titles' do
    let(:mock_solr) { double('solr_connection') }

    before do
      allow(Blacklight).to receive_message_chain(:default_index, :connection)
        .and_return(mock_solr)
    end

    context 'with a normal search term' do
      it 'returns http success and calls Solr' do
        allow(mock_solr).to receive(:get).and_return(
          'response' => { 'docs' => [] }
        )
        get :titles, params: { term: 'history' }
        expect(response).to have_http_status(:ok)
      end

      it 'includes the escaped term in the Solr query' do
        expect(mock_solr).to receive(:get).with('select', hash_including(
          params: hash_including(q: a_string_including('history'))
        )).and_return('response' => { 'docs' => [] })

        get :titles, params: { term: 'history' }
      end
    end

    context 'with Solr Local Parameter injection attempt {!lucene}' do
      it 'does not forward raw {!lucene} to Solr' do
        captured_params = nil
        allow(mock_solr).to receive(:get) do |_path, opts|
          captured_params = opts[:params]
          { 'response' => { 'docs' => [] } }
        end

        get :titles, params: { term: '{!lucene}foo' }

        expect(captured_params[:q]).not_to match(/\{!/)
        expect(captured_params[:q]).not_to include('{')
        expect(captured_params[:q]).not_to include('!')
      end

      it 'enforces defType edismax in every Solr request' do
        allow(mock_solr).to receive(:get).and_return('response' => { 'docs' => [] })
        get :titles, params: { term: '{!raw f=id}*' }
        # defType must be present so Solr ignores any parser override
        expect(mock_solr).to have_received(:get).with('select', hash_including(
          params: hash_including(defType: 'edismax')
        ))
      end
    end

    context 'with a term shorter than 2 characters' do
      it 'returns an empty JSON array without querying Solr' do
        expect(mock_solr).not_to receive(:get)
        get :titles, params: { term: 'a' }
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end
end
