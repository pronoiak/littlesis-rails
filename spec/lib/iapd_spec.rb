require 'sqlite3'
require Rails.root.join('lib/iapd_importer.rb')

describe "Iapd Dataset" do
  let(:db) do
    SQLite3::Database.new(":memory:", results_as_hash: true).tap do |db|
      db.execute_batch2 <<SQL
CREATE TABLE advisors(
  crd_number TEXT,
  names,
  filing_ids,
  sec_file_numbers,
  first_filename,
  latest_filename,
  latest_aum,
  latest_filing_id
);

CREATE TABLE owners_schedule_a(
  records,
  filing_ids,
  owner_key,
  advisor_crd_number TEXT
);

INSERT INTO advisors (crd_number, names, filing_ids, first_filename, latest_filename, latest_aum, latest_filing_id)
       VALUES ('1', '["Wealth Advisors LLC"]', '[123]', 'file0', 'file1', '1000', 123);

INSERT INTO advisors (crd_number, names, filing_ids, first_filename, latest_filename, latest_aum, latest_filing_id)
       VALUES ('2', '["Billionaire Advisors"]', '[456]', 'file0', 'file1', '2000', 456);

INSERT INTO owners_schedule_a (records, filing_ids, owner_key, advisor_crd_number)
       VALUES('[{"filing_id":123,"schedule":"A","scha_3":"Y","name":"Rich Owner","owner_type":"E","title_or_status":"CEO","acquired":"11/2019","ownership_code":"B","control_person":"N","public_reporting":"N","owner_id":"3","filename":"file1","iapd_year":"2019"}]', '[123]', '3', '1');

INSERT INTO owners_schedule_a (records, filing_ids, owner_key, advisor_crd_number)
       VALUES ('[{"filing_id":456,"schedule":"A","scha_3":"Y","name":"Rich Owner","owner_type":"E","title_or_status":"BOARD MEMBER","acquired":"01/2018","ownership_code":"B","control_person":"N","public_reporting":"N","owner_id":"3","filename":"file1","iapd_year":"2019"}]', '[456]', '3', '2');

SQL
    end
  end

  before { allow(IapdImporter).to receive(:db).and_return(db) }

  describe 'import' do
    it 'creates 4 ExternalData' do
      expect { IapdImporter.run }.to change(ExternalData, :count).by(4)
    end

    it 'does not import duplicates' do
      expect { IapdImporter.run }.to change(ExternalData, :count).by(4)
      expect { IapdImporter.run }.not_to change(ExternalData, :count)
    end
  end

  xdescribe 'processor' do
    before do
      IapdImporter.run
      create(:tag, name: 'iapd')
    end

    it 'creates 3 ExternalEntity' do
      expect { IapdProcessor.run }.to change(ExternalEntity, :count).by(3)
    end

    it 'can automatch Rich Owner' do
      entity = create(:entity_person, name: 'Rich Owner').tap { |e| e.external_links.crd.create!(link_id: '3') }
      IapdProcessor.run
      expect(ExternalEntity.find_by(external_data: ExternalData.iapd_owners.find_by(dataset_id: '3')).entity_id)
        .to eq entity.id
    end

    it 'creates 3 ExternalRelationship' do
      expect { IapdProcessor.run }.to change(ExternalRelationship, :count).by(3)
    end

    xit 'duplicate runs have no effect' do
      expect do
        2.times { IapdProcessor.run }
      end.to change(ExternalRelationship, :count).by(2)
    end
  end
end
