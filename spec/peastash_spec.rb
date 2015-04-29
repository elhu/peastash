require 'spec_helper'

describe Peastash do

  after(:each) { unconfigure_foostash! }

  describe 'enabled' do

    before :each do
      Peastash.any_instance.stub(:enabled?) { true }
    end

    describe "scoped instances" do
      it 'always return the same instance for the same name' do
        expect(Peastash.with_instance(:foo)).to be(Peastash.with_instance(:foo))
      end

      it 'returns different instances for different names' do
        expect(Peastash.with_instance(:bar)).to_not be(Peastash.with_instance(:foo))
      end

      it 'uses `global` as the default instance name' do
        expect(Peastash.with_instance(:global)).to be(Peastash.with_instance)
      end

      it 'inherits its configuration for the `global` conf' do
        Peastash.with_instance(:global).configure!({source: :foo})
        expect(Peastash.with_instance(:bar).configuration[:source]).to be(:foo)
      end
    end

    describe "#configure!" do
      it 'allows setting tags to be added to every event' do
        tags = ['foo', 'bar']
        Peastash.with_instance.configure!(tags: tags)
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => an_instance_of(Hash),
          '@tags' => tags,
          '@pid' => an_instance_of(Fixnum),
        })
        Peastash.with_instance.log {}
      end

      it "can customize the source" do
        Peastash.with_instance.configure!(source: 'foo')
        expect(LogStash::Event).to receive(:new).with({
          '@source' => 'foo',
          '@fields' => an_instance_of(Hash),
          '@tags' => [],
          '@pid' => an_instance_of(Fixnum),
        })
        Peastash.with_instance.log {}
      end

      it "can customize the store name" do
        Peastash.with_instance.configure!(store_name: :foo)
        Peastash.with_instance.store[:bar] = 'bar'
        expect(Thread.current[:global].keys).to include(:foo)
        expect(Thread.current[:global][:foo]).to eq(bar: 'bar')
      end

      context "dump if empty?" do
        it "can prevent logging if nothing is stored" do
          Peastash.with_instance.configure!(dump_if_empty: false)
          expect(Peastash.with_instance.instance_variable_get(:@output)).to_not receive(:dump)
          Peastash.with_instance.log {}
        end

        it "doesn't prevent logging if set to true" do
          Peastash.with_instance.configure!(dump_if_empty: true)
          expect(Peastash.with_instance.instance_variable_get(:@output)).to receive(:dump)
          Peastash.with_instance.log {}
        end
      end
    end

    describe "#log" do
      context "Peastash not configured" do
        it "calls #configure! beforehand" do
          expect(Peastash.with_instance).to receive(:configure!).once.and_call_original
          Peastash.with_instance.log {}
        end
      end

      context "Peastash already configured" do
        before { Peastash.with_instance.configure! }

        it "doesn't call #configure!" do
          expect(Peastash).to_not receive(:configure!)
          Peastash.with_instance.log {}
        end
      end

      it "sends the event to the output" do
        Peastash.with_instance.configure!
        expect(Peastash.with_instance.instance_variable_get(:@output)).to receive(:dump)
        Peastash.with_instance.log {}
      end

      it "clears the store beforehand" do
        Peastash.with_instance.configure!
        Peastash.with_instance.store[:foo] = 'bar'
        Peastash.with_instance.log {}
        expect(Peastash.with_instance.store.keys).to_not include(:foo)
      end

      it "aggregates everything in the store and dumps it" do
        Peastash.with_instance.configure!
        Peastash.with_instance.log do
          Peastash.with_instance.store[:foo] = ['foo']
          Peastash.with_instance.store[:foo] << 'bar'
        end
        expect(Peastash.with_instance.store[:foo]).to eq(['foo', 'bar'])
      end

      it "merges the tags from the parameters with the base tags" do
        base_tags = %w(foo bar)
        tags = %w(baz)
        Peastash.with_instance.configure!(tags: base_tags)
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => an_instance_of(Hash),
          '@tags' => base_tags + tags,
          '@pid' => an_instance_of(Fixnum),
        })
        Peastash.with_instance.log(tags) {}
      end
    end

    describe ".safely" do
      context "when safe" do
        before { Peastash.safe! }

        it 'rescues errors silently' do
          expect {
            Peastash.safely { 1 / 0 }
          }.not_to raise_error
        end

        it 'returns value returned from the block' do
          expect(Peastash.safely { "test" }).to eq("test")
        end

        it "puts the error to STDERR for easy debugging" do
          expect(STDERR).to receive(:puts)
          Peastash.safely { 1 / 0 }
        end
      end

      context "when unsafe" do
        before { Peastash.unsafe! }

        it 'doesn\'t rescue errors silently' do
          expect {
            Peastash.safely { 1 / 0 }
          }.to raise_error(ZeroDivisionError)
        end

        it "puts the error to STDERR for easy debugging" do
          expect(STDERR).to receive(:puts)

          expect {
            Peastash.safely { 1 / 0 }
          }.to raise_error(ZeroDivisionError)
        end
      end
    end

    describe "#tags" do
      it "calls configure beforehand if instance isn't configured" do
        expect(Peastash.with_instance).to receive(:configure!).and_call_original
        Peastash.with_instance.tags << 'foo'
      end

      it "makes it possible to add tags from within the #log block" do
        base_tags = %w(foo bar)
        tags = %w(baz)
        additional_tags = %w(qux)
        Peastash.with_instance.configure!(tags: base_tags)
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => an_instance_of(Hash),
          '@tags' => base_tags + tags + additional_tags,
          '@pid' => an_instance_of(Fixnum),
        })
        Peastash.with_instance.log(tags) { Peastash.with_instance.tags.concat(additional_tags) }
      end
    end

  end

  describe 'disabled' do

    it "can process the called stuff in the #log block" do
      expect {
        Peastash.with_instance.log do
          raise
        end
      }.to raise_error
    end

    it "can process the called stuff in the #log block" do
      expect { |b|
        Peastash.with_instance.log(&b)
      }.to yield_with_args(Peastash.with_instance)
    end

    it "can process the called stuff for custom instance in the #log block" do
      expect { |b|
        Peastash.with_instance(:worker).log(&b)
      }.to yield_with_args(Peastash.with_instance(:worker))
    end

  end

end
