require_relative '../source/database_service'

RSpec.describe DatabaseService do
  let(:player_name) { 'steph-curry' }
  let(:dynamodb_client) { double }

  subject { described_class.new(player_name) }

  before do
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamodb_client)
  end

  describe '#create_records' do
    context 'when player data is empty' do
      let(:player_data) { [] }

      it 'does not create any records' do
        res = subject.create_records(player_data)
        expect(res).to eq("#{player_name}: upserted 0 record(s)")
      end
    end

    context 'when player data already exists in database' do
      let(:player_data) do
        [ { 'date'=>'2022-11-03', 'opponent'=>'BOS', '3fga'=>'17', '3fgm'=>'8' } ]
      end

      it 'does not create any records' do
        query_results = double(items: [{ 'game_date' => '2022-11-03' }])
        expect(dynamodb_client).to receive(:query).once.and_return(query_results)

        res = subject.create_records(player_data)
        expect(res).to eq("#{player_name}: upserted 0 record(s)")
      end
    end

    context 'when player data has 1 game that exists and 1 that does not exist in database' do
      let(:player_data) do
        [
          { 'date'=>'2022-11-03', 'opponent'=>'BOS', '3fga'=>'17', '3fgm'=>'8' },
          { 'date'=>'2022-11-05', 'opponent'=>'@NY', '3fga'=>'14', '3fgm'=>'10' }
        ]
      end

      it 'creates record' do
        query_results = double(items: [{ 'game_date' => '2022-11-03' }])
        expect(dynamodb_client).to receive(:query).once.and_return(query_results)

        expect(dynamodb_client).to receive(:put_item).with(
          table_name: 'splash-brothers-stats',
          item: {
            'player_name' => player_name,
            'game_date' => '2022-11-05',
            'opponent' => 'NY',
            'at_home' => false,
            'fg3a' => 14,
            'fg3m' => 10
          }
        ).once.and_return(1)

        res = subject.create_records(player_data)
        expect(res).to eq("#{player_name}: upserted 1 record(s)")
      end
    end

    context 'when player data does not exist in database' do
      let(:player_data) do
        [
          { 'date'=>'2022-11-03', 'opponent'=>'vs BOS', '3fga'=>'17', '3fgm'=>'8' },
          { 'date'=>'2022-11-05', 'opponent'=>'@NY', '3fga'=>'14', '3fgm'=>'10' }
        ]
      end

      it 'creates records' do
        query_results = double(items: [])
        expect(dynamodb_client).to receive(:query).once.and_return(query_results)

        expect(dynamodb_client).to receive(:put_item).with(
          table_name: 'splash-brothers-stats',
          item: {
            'player_name' => player_name,
            'game_date' => '2022-11-03',
            'opponent' => 'BOS',
            'at_home' => true,
            'fg3a' => 17,
            'fg3m' => 8
          }
        ).once.and_return(1)

        expect(dynamodb_client).to receive(:put_item).with(
          table_name: 'splash-brothers-stats',
          item: {
            'player_name' => player_name,
            'game_date' => '2022-11-05',
            'opponent' => 'NY',
            'at_home' => false,
            'fg3a' => 14,
            'fg3m' => 10
          }
        ).once.and_return(1)

        res = subject.create_records(player_data)
        expect(res).to eq("#{player_name}: upserted 2 record(s)")
      end
    end
  end

  describe '#parse_opponent' do
    it { expect(subject.send(:parse_opponent, '@SAC')).to eq([false, 'SAC']) }
    it { expect(subject.send(:parse_opponent, '@ LAL')).to eq([false, 'LAL']) }
    it { expect(subject.send(:parse_opponent, 'vs LAC')).to eq([true, 'LAC']) }
    it { expect(subject.send(:parse_opponent, 'vsPOR')).to eq([true, 'POR']) }
  end
end
