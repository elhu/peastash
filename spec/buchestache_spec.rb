require 'spec_helper'

describe Buchestache do
  after(:each) { unconfigure_foostash! }

  describe "scoped instances" do
    it 'always return the same instance for the same name' do
      expect(Buchestache.instance(:foo)).to be(Buchestache.instance(:foo))
    end

    it 'returns different instances for different names' do
      expect(Buchestache.instance(:bar)).to_not be(Buchestache.instance(:foo))
    end

    it 'uses `global` as the default instance name' do
      expect(Buchestache.instance(:global)).to be(Buchestache.instance)
    end
  end

  describe "#configure!" do
    it 'allows setting tags to be added to every event' do
      tags = ['foo', 'bar']
      Buchestache.instance.configure!(tags: tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => tags
      })
      Buchestache.instance.log {}
    end

    it "can customize the source" do
      Buchestache.instance.configure!(source: 'foo')
      expect(LogStash::Event).to receive(:new).with({
        '@source' => 'foo',
        '@fields' => {},
        '@tags' => []
      })
      Buchestache.instance.log {}
    end

    it "can customize the store name" do
      Buchestache.instance.configure!(store_name: :foo)
      Buchestache.instance.store[:bar] = 'bar'
      expect(Thread.current[:global].keys).to include(:foo)
      expect(Thread.current[:global][:foo]).to eq(bar: 'bar')
    end

    context "dump if empty?" do
      it "can prevent logging if nothing is stored" do
        Buchestache.instance.configure!(dump_if_empty: false)
        expect(Buchestache.instance.instance_variable_get(:@output)).to_not receive(:dump)
        Buchestache.instance.log {}
      end

      it "doesn't prevent logging if set to true" do
        Buchestache.instance.configure!(dump_if_empty: true)
        expect(Buchestache.instance.instance_variable_get(:@output)).to receive(:dump)
        Buchestache.instance.log {}
      end
    end
  end

  describe "#log" do
    context "Buchestache not configured" do
      it "calls #configure! beforehand" do
        expect(Buchestache.instance).to receive(:configure!).once.and_call_original
        Buchestache.instance.log {}
      end
    end

    context "Buchestache already configured" do
      before { Buchestache.instance.configure! }

      it "doesn't call #configure!" do
        expect(Buchestache).to_not receive(:configure!)
        Buchestache.instance.log {}
      end
    end

    it "sends the event to the output" do
      Buchestache.instance.configure!
      expect(Buchestache.instance.instance_variable_get(:@output)).to receive(:dump)
      Buchestache.instance.log {}
    end

    it "clears the store beforehand" do
      Buchestache.instance.configure!
      Buchestache.instance.store[:foo] = 'bar'
      Buchestache.instance.log {}
      expect(Buchestache.instance.store.keys).to_not include(:foo)
    end

    it "aggregates everything in the store and dumps it" do
      Buchestache.instance.configure!
      Buchestache.instance.log do
        Buchestache.instance.store[:foo] = ['foo']
        Buchestache.instance.store[:foo] << 'bar'
      end
      expect(Buchestache.instance.store[:foo]).to eq(['foo', 'bar'])
    end

    it "merges the tags from the parameters with the base tags" do
      base_tags = %w(foo bar)
      tags = %w(baz)
      Buchestache.instance.configure!(tags: base_tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => base_tags + tags
      })
      Buchestache.instance.log(tags) {}
    end
  end

  describe "#tags" do
    it "makes it possible to add tags from within the #log block" do
      base_tags = %w(foo bar)
      tags = %w(baz)
      additional_tags = %w(qux)
      Buchestache.instance.configure!(tags: base_tags)
      expect(LogStash::Event).to receive(:new).with({
        '@source' => Buchestache::STORE_NAME,
        '@fields' => {},
        '@tags' => base_tags + tags + additional_tags
      })
      Buchestache.instance.log(tags) { Buchestache.instance.tags.concat(additional_tags) }
    end
  end

end
