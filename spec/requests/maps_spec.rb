describe 'Maps', :sphinx, type: :request do
  describe 'featuring maps' do
    as_basic_user do
      let(:map) { create(:network_map, user_id: User.last.id) }
      let(:url) { Rails.application.routes.url_helpers.feature_map_path(map) }
      before { post url, params: { action: 'ADD' } }
      denies_access
    end
  end

  describe 'oligrapher search api' do
    before(:all) do
      setup_sphinx 'entity_core' do
        @apple_corp = create(:entity_org, name: 'apple corp')
        @banana_corp = create(:entity_org, name: 'banana! corp')
      end
    end

    after(:all) do
      teardown_sphinx { delete_entity_tables }
    end

    describe 'find nodes' do
      describe 'missing param q' do
        before { get '/maps/find_nodes' }
        specify { expect(response).to have_http_status 400 }
      end

      describe 'searching for "apple"' do
        before { get '/maps/find_nodes', params: { q: 'apple' } }

        it 'finds one entity and returns search results as json' do
          expect(response).to have_http_status 200
          expect(json.length).to eql(1)
          expect(ActiveSupport::HashWithIndifferentAccess.new(json.first))
            .to eql ActiveSupport::HashWithIndifferentAccess.new(Oligrapher.legacy_entity_to_node(@apple_corp))
        end
      end

      describe 'searching for "banana!"' do
        before { get '/maps/find_nodes', params: { q: 'banana!' } }

        it 'finds one entity and returns search results as json' do
          expect(response).to have_http_status 200
          expect(json.length).to eql(1)
          expect(ActiveSupport::HashWithIndifferentAccess.new(json.first))
            .to eql ActiveSupport::HashWithIndifferentAccess.new(Oligrapher.legacy_entity_to_node(@banana_corp))
        end
      end
    end
  end

  describe 'creating new maps' do
    let(:request_params) do
      { title: 'so many connections',
        data: JSON.dump({"entities"=>[], "rels"=>[], "texts"=>[]}),
        graph_data: JSON.dump({"nodes"=>{}, "edges"=>{}, "captions"=>{}}),
        width: 960,
        height: 960,
        annotations_data: [],
        annotations_count: 0,
        is_private: false,
        is_cloneable: true }
    end

    let(:post_maps) do
      -> { post '/maps', params: request_params }
    end

    context 'with anon user' do
      before { post_maps.call }

      redirects_to_login
    end

    context 'with basic user' do
      let(:user) { create_basic_user }

      before { login_as(user, :scope => :user) }

      after { logout(:user) }

      it 'creates a new map' do
        expect(&post_maps).to change(NetworkMap, :count).by(1)
      end

      it 'sets sf_user_id' do
        post_maps.call
        expect(NetworkMap.last.sf_user_id).to eql user.sf_guard_user_id
      end

      it 'sets user_id' do
        post_maps.call
        expect(NetworkMap.last.user_id).to eql user.id
      end
    end
  end

  describe 'cloning' do
    let(:map_owner) { create_basic_user }
    let(:other_user) { create_basic_user }
    let(:map) { create(:network_map, user_id: map_owner.id, is_private: false, is_cloneable: true) }
    let(:not_cloneable) { create(:network_map, user_id: map_owner.id, is_private: false, is_cloneable: false) }

    before do
      login_as(other_user, :scope => :user)
    end

    after { logout(:user) }

    it 'creates a new maps and clones' do
      map
      clone_request = -> { post "/maps/#{map.id}/clone" }
      expect(&clone_request).to change(NetworkMap, :count).by(1)
      expect(response).to have_http_status :found

      last_created_map = NetworkMap.last
      expect(last_created_map.title.slice(0, 6)).to eq 'Clone:'
      expect(last_created_map.user_id).to eq other_user.id
      expect(last_created_map.sf_user_id).to eq other_user.sf_guard_user_id
    end

    it 'does not clone the map if the map is not cloneable' do
      not_cloneable
      clone_request = -> { post "/maps/#{not_cloneable.id}/clone" }
      expect(&clone_request).not_to change(NetworkMap, :count)

      expect(response).to have_http_status :unauthorized
    end
  end
end
