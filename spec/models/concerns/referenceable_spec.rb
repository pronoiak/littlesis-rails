require 'rails_helper'

describe Referenceable, type: :model do
  module Assocations
    def has_many(*args); end
  end

  class TestReferenceable
    attr_reader :id
    extend Assocations
    include ActiveModel::Validations
    include Referenceable

    @@id = 0

    def initialize
      @@id += 1
      @id = @@id
      
    end

    def references; end

    def persisted?
      true
    end
  end

  describe 'add_reference' do
    let(:referenceable) { TestReferenceable.new }
    let(:url) { Faker::Internet.unique.url }
    let(:url_name) { Faker::Lorem.sentence }
    let(:attributes) { { url: url, name: url_name } }
    let(:add_reference) { proc { referenceable.add_reference(attributes) } }

    def creates_new_reference
      expect(referenceable).to receive(:references)
                                 .twice.and_return(double(:create => nil, :exists? => false))
    end

    def does_not_create_new_reference
      expect(referenceable).to receive(:references).once
                                 .and_return(double(:exists? => true))
    end

    it 'throws if called on a record that has not yet been saved' do
      expect(referenceable).to receive(:persisted?).and_return(false)
      expect { add_reference.call }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it 'throws if attributes do not include the key :url' do
      expect { referenceable.add_reference(foo: 'bar') }.to raise_error(ArgumentError)
    end

    context 'submitted with invalid url' do
      let(:url) { 'not-a-url' }

      it 'does not create a new document' do
        expect { add_reference.call }.not_to change { Document.count }
      end
      
      it 'adds an error to the record' do
        expect(referenceable.valid?).to be true
        add_reference.call
        expect(referenceable.valid?).to be false
        expect(referenceable.errors[:base].first).to eql 'not-a-url is not a valid url'
      end
    end

    context 'no existing Document or Reference' do
      it 'creates a new document' do
        creates_new_reference
        expect { add_reference.call }.to change { Document.count }.by(1)
      end

      it 'creates a new reference' do
        creates_new_reference
        add_reference.call
      end

      it 'returns self' do
        creates_new_reference
        expect(add_reference.call).to eql referenceable
      end
    end

    context 'existing Document, but no existing Reference' do
      before { Document.create!(url: url, name: url_name) }

      it 'does not create a new document' do
        creates_new_reference
        expect { add_reference.call }.not_to change { Document.count }
      end

      it 'creates a new reference' do
        creates_new_reference
        add_reference.call
      end
    end

    context 'existing Document and Reference' do
      before { Document.create!(url: url, name: url_name) }

      it 'does not create a new document or reference' do
        does_not_create_new_reference
        expect { add_reference.call }.not_to change { Document.count }
      end
    end

    # What should we do in this situation?
    context 'existing Document, with different name'
  end
end
