require 'rails_helper'

describe 'Relationships Requests' do
  let(:user) { create_really_basic_user }
  before(:each) { login_as(user, :scope => :user) }
  after(:each) { logout(:user) }

  let(:person) { create(:entity_person, :with_person_name) }
  let(:org) { create(:entity_org, :with_org_name) }

  describe 'Creating Relationships' do
    let(:params) do
      {
        relationship: {
          entity1_id: person.id,
          entity2_id: org.id,
          category_id: 1,
          is_current: 'YES',
          description1: 'Director'
        },
        reference: attributes_for(:document)
      }
    end

    subject { -> { post relationships_path, params: params } }

    context 'valid position relationship' do
      it { is_expected.to change { Relationship.count }.by(1) }
      it { is_expected.to change { Reference.count }.by(1) }

      it do
        is_expected.to change { person.reload.last_user_id }.to(user.sf_guard_user.id)
      end

      it do
        is_expected.to change { org.reload.last_user_id }.to(user.sf_guard_user.id)
      end

      it 'responds with json containing the relationship id' do
        subject.call
        expect(json).to eql('relationship_id' => Relationship.last.id)
      end

      context 'is board membership' do
        before do
          params[:relationship][:position_attributes] = { is_board: 'true' }
        end

        it { is_expected.to change { Relationship.count }.by(1) }

        it 'corrects updates "is_board" on position' do
          expect(&subject).to change { Position.count }.by(1)
          expect(Position.last.is_board).to eql true
        end
      end
    end

    context 'with invalid url' do
      before { params[:reference][:url] = 'I AM A BAD URL' }
      it { is_expected.not_to change { Relationship.count } }

      it 'rends json of errors' do
        subject.call
        expect(response).to have_http_status :bad_request
        expect(response.body).to include 'is not a valid url'
      end
    end

    context 'with amount amount field' do
      before { params[:relationship][:amount] = '$25,000' }
      it { is_expected.to change { Relationship.count }.by(1) }

      it 'adds amount field to relationship' do
        subject.call
        expect(Relationship.last.amount).to eql 25_000
      end
    end
  end

  describe 'Updating relationships' do
    let(:notes) { Faker::Lorem.sentence }

    describe 'Position Relationship' do
      let(:position_relationship) do
        Relationship
          .create!(category_id: 1, entity: person, related: org, description1: 'Lobbyist')
          .tap { |r| r.position.update_columns(is_executive: true) }
      end

      let(:base_params) do
        {
          reference: { just_cleaning_up: 1, url: nil, name: nil },
          relationship: {
            description1: 'Lobbyist',
            start_date: '2009',
            end_date: nil,
            is_current: nil,
            notes: notes,
            position_attributes: {
              is_board: 'true',
              is_executive: 'true',
              is_employee: nil,
              compensation: nil,
              id: position_relationship.position.id
            }
          }
        }
      end
      let(:params) { base_params }
      let(:patch_request) { proc { patch relationship_path(position_relationship), params: params } }

      context 'updating relationship fields' do
        
        it 'redirects to relationship page' do
          patch_request.call
          redirects_to_path relationship_path(position_relationship)
        end

        it 'updates relationship fields and position fields' do
          expect(position_relationship.start_date).to be_nil
          expect(position_relationship.notes).to be_nil
          expect(position_relationship.position.is_board).to be_nil
          expect(position_relationship.position.is_executive).to be true
          patch_request.call
          position_relationship.reload
          expect(position_relationship.start_date).to eql '2009-00-00'
          expect(position_relationship.position.is_board).to be true
          expect(position_relationship.position.is_executive).to be true
          expect(position_relationship.notes).to eql notes
          expect(position_relationship.entity1_id).to eql person.id
        end
      end

      context 'submitting an invalid date' do
        let(:params) { base_params.deep_merge(relationship: { start_date: 'BAD DATE' }) }
        before { patch_request.call }
        renders_the_edit_page

        it 'does not change the relationship' do
          expect(position_relationship.reload.start_date).to be nil
          expect(position_relationship.reload.notes).to be nil
        end
      end
    end # Position Relationship

    describe 'Transaction Relationship' do
      let(:entity1) { create(:entity_org, :with_org_name) }
      let(:entity2) { create(:entity_org, :with_org_name) }

      let(:transaction_relationship) do
        Relationship.create!(category_id: Relationship::TRANSACTION_CATEGORY,
                             entity: entity1,
                             related: entity2,
                             description1: 'Contractor',
                             description2: 'Client')
      end

      let(:base_params) do
        {
          reference: { just_cleaning_up: 1, url: nil, name: nil },
          relationship: {
            description1: 'Contractor',
            description2: 'Client',
            start_date: '',
            end_date: '',
            is_current: '',
            notes: '',
            trans_attributes: { is_lobbying: 'true' }
          }
        }
      end
      let(:params) { base_params }
      let(:patch_request) { proc { patch relationship_path(transaction_relationship), params: params } }

      def self.updates_transaction_fields
        it 'upates relationship and transaction fields' do
          expect(transaction_relationship.trans.is_lobbying).to be_nil
          patch_request.call
          transaction_relationship.reload
          redirects_to_path relationship_path(transaction_relationship)
          expect(transaction_relationship.trans.is_lobbying).to be true
        end
      end

      context 'updating without reversing' do
        let(:params) { base_params.deep_merge(reverse_direction: 'false') }

        updates_transaction_fields

        it 'does not reverse the relationship' do
          patch_request.call
          transaction_relationship.reload
          expect(transaction_relationship.trans.is_lobbying).to be true
          expect(transaction_relationship.entity1_id).to eql entity1.id
          expect(transaction_relationship.entity2_id).to eql entity2.id
        end
      end

      context 'updating AND reversing' do
        let(:params) { base_params.deep_merge(reverse_direction: 'true') }

        updates_transaction_fields

        it 'reverses the relationship' do
          patch_request.call
          transaction_relationship.reload
          expect(transaction_relationship.trans.is_lobbying).to be true
          expect(transaction_relationship.entity1_id).to eql entity2.id
          expect(transaction_relationship.entity2_id).to eql entity1.id
        end
      end
    end # end updating and reversing
  end # end updating relationships

  describe 'deleting relationships' do
    # let(:user) { create_admin_user }
    let(:entity) { create(:entity_org) }
    let(:related) { create(:entity_person) }
    let!(:relationship) do
      create(:generic_relationship, entity: entity, related: related, last_user_id: 1)
    end
    subject { -> { delete relationship_path(relationship), params: { id: relationship.id } } }

    context 'as a regular user' do
      before { subject.call }
      denies_access
    end

    context 'as an admin user' do
      let(:user) { create_admin_user }
      it { is_expected.to change { Relationship.count }.by(-1) }
      it { is_expected.to change { entity.reload.last_user_id }.from(1).to(user.sf_guard_user_id) }
      it { is_expected.to change { related.reload.last_user_id }.from(1).to(user.sf_guard_user_id) }
      it 'redirects to dashboard' do
        subject.call
        redirects_to_path home_dashboard_path
      end
    end
  end
end
