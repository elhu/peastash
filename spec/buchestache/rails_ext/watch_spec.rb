require 'buchestache/rails_ext/watch'

describe "Buchestache::Watch" do
  it "adds the #watch method to Buchestache" do
    expect(Buchestache).to respond_to(:watch)
  end

  describe "#watch" do
    it "can subscribe to any notification" do
      @dummy = Object.new.stub(:foo)
      @subscriber = Buchestache.watch('foo.bar') { @dummy.foo }
      expect(@dummy).to receive(:foo)
      ActiveSupport::Notifications.instrument('foo.bar')
      ActiveSupport::Notifications.unsubscribe(@subscriber)
    end

    it "is provided with a handy named store" do
      Buchestache.watch('foo.bar') { |*event, store| store[:foo] = 'bar' }
      @subscriber = ActiveSupport::Notifications.instrument('foo.bar')
      expect(Buchestache.store['foo.bar']).to eq(foo: 'bar')
    end
  end
end
