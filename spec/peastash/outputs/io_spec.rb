require 'spec_helper'
require 'peastash/outputs/io'

describe Peastash::Outputs::IO do
  it 'creates a logdevice' do
    io = Peastash::Outputs::IO.new('/dev/null', shift_size: 10)
    expect(io.instance_variable_get("@device").instance_variable_get("@shift_size")).to eq(10)
  end
end
