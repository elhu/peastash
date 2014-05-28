require 'spec_helper'

describe Buchestache do
  after(:each) { unconfigure_foostash! }

  describe "#configure!" do
    it 'allows setting tags to be added to every event' do
      tags = ['foo', 'bar']
      Buchestache.configure!(tags: tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => tags
      })
      Buchestache.log {}
    end

    it "can customize the source" do
      Buchestache.configure!(source: 'foo')
      expect(LogStash::Event).to receive(:new).with({
        '@source' => 'foo',
        '@fields' => {},
        '@tags' => []
      })
      Buchestache.log {}
    end

    it "can customize the store name" do
      Buchestache.configure!(store_name: :foo)
      Buchestache.store[:bar] = 'bar'
      expect(Thread.current.keys).to include(:foo)
      expect(Thread.current['foo']).to eq(bar: 'bar')
    end

    context "dump if empty?" do
      it "can prevent logging if nothing is stored" do
        Buchestache.configure!(dump_if_empty: false)
        expect(Buchestache.instance_variable_get(:@output)).to_not receive(:dump)
        Buchestache.log {}
      end

      it "doesn't prevent logging if set to true" do
        Buchestache.configure!(dump_if_empty: true)
        expect(Buchestache.instance_variable_get(:@output)).to receive(:dump)
        Buchestache.log {}
      end
    end
  end

  describe "#log" do
    context "Buchestache not configured" do
      it "calls #configure! beforehand" do
        expect(Buchestache).to receive(:configure!).once.and_call_original
        Buchestache.log {}
      end
    end

    context "Buchestache already configured" do
      before { Buchestache.configure! }

      it "doesn't call #configure!" do
        expect(Buchestache).to_not receive(:configure!)
        Buchestache.log {}
      end
    end

    it "sends the event to the output" do
      Buchestache.configure!
      expect(Buchestache.instance_variable_get(:@output)).to receive(:dump)
      Buchestache.log {}
    end

    it "clears the store beforehand" do
      Buchestache.configure!
      Buchestache.store[:foo] = 'bar'
      Buchestache.log {}
      expect(Buchestache.store.keys).to_not include(:foo)
    end

    it "aggregates everything in the store and dumps it" do
      Buchestache.configure!
      Buchestache.log do
        Buchestache.store[:foo] = ['foo']
        Buchestache.store[:foo] << 'bar'
      end
      expect(Buchestache.store[:foo]).to eq(['foo', 'bar'])
    end

    it "merges the tags from the parameters with the base tags" do
      base_tags = %w(foo bar)
      tags = %w(baz)
      Buchestache.configure!(tags: base_tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => base_tags + tags
      })
      Buchestache.log(tags) {}
    end
  end

end
