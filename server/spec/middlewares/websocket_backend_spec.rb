require_relative '../spec_helper'
require_relative '../../app/middlewares/websocket_backend'

describe WebsocketBackend do
  let(:app) { spy(:app) }
  let(:subject) { described_class.new(app) }

  before(:each) do
    stub_const('Server::VERSION', '0.9.1')
  end

  describe '#our_version' do
    it 'retuns baseline version with patch level 0' do
      expect(subject.our_version).to eq('0.9.0')
    end
  end

  describe '#valid_agent_version?' do
    it 'returns true when exact match' do
      expect(subject.valid_agent_version?('0.9.1')).to eq(true)
    end

    it 'returns true when exact match with beta' do
      stub_const('Server::VERSION', '0.9.0.beta')
      expect(subject.valid_agent_version?('0.9.0.beta')).to eq(true)
    end

    it 'returns true when patch level is greater' do
      expect(subject.valid_agent_version?('0.9.2')).to eq(true)
    end

    it 'returns true when patch level is less than' do
      expect(subject.valid_agent_version?('0.9.0')).to eq(true)
    end

    it 'returns false when minor version is different' do
      expect(subject.valid_agent_version?('0.8.4')).to eq(false)
    end

    it 'returns false when major version is different' do
      expect(subject.valid_agent_version?('1.0.1')).to eq(false)
    end
  end

  describe '#subscribe_to_rpc_channel' do
    let(:client) do
      {
          ws: spy(:ws)
      }
    end

    it 'sends message if client is found' do
      allow(subject).to receive(:client_for_id).and_return(client)
      expect(subject).to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
    end

    it 'does not send message if client is not found' do
      expect(subject).not_to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
    end
  end

  describe '#on_pong' do
    let(:client) do
      { id: 'node_id', ws: spy(:ws) }
    end

    let(:grid) do
      Grid.create!(name: 'test')
    end

    let(:node) do
      HostNode.create!(name: 'test-node', node_id: 'aa', grid: grid)
    end

    it 'calls on_close if client is not found' do
      expect(subject).to receive(:on_close).with(client[:ws])
      subject.on_pong(client)
    end

    it 'triggers agent plug' do
      expect(Agent::NodePlugger).to receive(:new).and_return(spy)
      client[:id] = node.node_id
      subject.on_pong(client)
    end
  end
end
