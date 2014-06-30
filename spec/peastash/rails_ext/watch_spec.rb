require 'spec_helper'
require 'peastash/rails_ext/watch'

describe "Peastash::Watch" do
  it "adds the #watch method to Peastash" do
    expect(Peastash.with_instance).to respond_to(:watch)
  end

  describe "#watch" do
    it "can subscribe to any notification" do
      @dummy = Object.new.stub(:foo)
      @subscriber = Peastash.with_instance.watch('foo.bar') { @dummy.foo }
      expect(@dummy).to receive(:foo)
      ActiveSupport::Notifications.instrument('foo.bar')
      ActiveSupport::Notifications.unsubscribe(@subscriber)
    end

    it "is provided with a handy named store" do
      Peastash.with_instance.watch('foo.bar') { |*event, store| store[:foo] = 'bar' }
      @subscriber = ActiveSupport::Notifications.instrument('foo.bar')
      expect(Peastash.with_instance.store['foo.bar']).to eq(foo: 'bar')
    end
  end
end
