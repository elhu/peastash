require 'spec_helper'

describe Buchestache do
  after(:each) { unconfigure_foostash! }
  before :each do
    Buchestache.any_instance.stub(:enabled?) { true }
  end

  describe "scoped instances" do
    it 'always return the same instance for the same name' do
      expect(Buchestache.with_instance(:foo)).to be(Buchestache.with_instance(:foo))
    end

    it 'returns different instances for different names' do
      expect(Buchestache.with_instance(:bar)).to_not be(Buchestache.with_instance(:foo))
    end

    it 'uses `global` as the default instance name' do
      expect(Buchestache.with_instance(:global)).to be(Buchestache.with_instance)
    end

    it 'inherits its configuration for the `global` conf' do
      Buchestache.with_instance(:global).configure!({source: :foo})
      expect(Buchestache.with_instance(:bar).configuration[:source]).to be(:foo)
    end
  end

  describe "#configure!" do
    it 'allows setting tags to be added to every event' do
      tags = ['foo', 'bar']
      Buchestache.with_instance.configure!(tags: tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => tags
      })
      Buchestache.with_instance.log {}
    end

    it "can customize the source" do
      Buchestache.with_instance.configure!(source: 'foo')
      expect(LogStash::Event).to receive(:new).with({
        '@source' => 'foo',
        '@fields' => {},
        '@tags' => []
      })
      Buchestache.with_instance.log {}
    end

    it "can customize the store name" do
      Buchestache.with_instance.configure!(store_name: :foo)
      Buchestache.with_instance.store[:bar] = 'bar'
      expect(Thread.current[:global].keys).to include(:foo)
      expect(Thread.current[:global][:foo]).to eq(bar: 'bar')
    end

    context "dump if empty?" do
      it "can prevent logging if nothing is stored" do
        Buchestache.with_instance.configure!(dump_if_empty: false)
        expect(Buchestache.with_instance.instance_variable_get(:@output)).to_not receive(:dump)
        Buchestache.with_instance.log {}
      end

      it "doesn't prevent logging if set to true" do
        Buchestache.with_instance.configure!(dump_if_empty: true)
        expect(Buchestache.with_instance.instance_variable_get(:@output)).to receive(:dump)
        Buchestache.with_instance.log {}
      end
    end
  end

  describe "#log" do
    context "Buchestache not configured" do
      it "calls #configure! beforehand" do
        expect(Buchestache.with_instance).to receive(:configure!).once.and_call_original
        Buchestache.with_instance.log {}
      end
    end

    context "Buchestache already configured" do
      before { Buchestache.with_instance.configure! }

      it "doesn't call #configure!" do
        expect(Buchestache).to_not receive(:configure!)
        Buchestache.with_instance.log {}
      end
    end

    it "sends the event to the output" do
      Buchestache.with_instance.configure!
      expect(Buchestache.with_instance.instance_variable_get(:@output)).to receive(:dump)
      Buchestache.with_instance.log {}
    end

    it "clears the store beforehand" do
      Buchestache.with_instance.configure!
      Buchestache.with_instance.store[:foo] = 'bar'
      Buchestache.with_instance.log {}
      expect(Buchestache.with_instance.store.keys).to_not include(:foo)
    end

    it "aggregates everything in the store and dumps it" do
      Buchestache.with_instance.configure!
      Buchestache.with_instance.log do
        Buchestache.with_instance.store[:foo] = ['foo']
        Buchestache.with_instance.store[:foo] << 'bar'
      end
      expect(Buchestache.with_instance.store[:foo]).to eq(['foo', 'bar'])
    end

    it "merges the tags from the parameters with the base tags" do
      base_tags = %w(foo bar)
      tags = %w(baz)
      Buchestache.with_instance.configure!(tags: base_tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => base_tags + tags
      })
      Buchestache.with_instance.log(tags) {}
    end
  end

  describe "#tags" do
    it "makes it possible to add tags from within the #log block" do
      base_tags = %w(foo bar)
      tags = %w(baz)
      additional_tags = %w(qux)
      Buchestache.with_instance.configure!(tags: base_tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => base_tags + tags + additional_tags
      })
      Buchestache.with_instance.log(tags) { Buchestache.with_instance.tags.concat(additional_tags) }
    end
  end

end
