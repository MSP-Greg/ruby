# encoding: binary
require_relative '../../../spec_helper'
require_relative '../fixtures/classes'
require_relative 'shared/basic'
require_relative 'shared/string'
require_relative 'shared/taint'

describe "Array#pack with format 'A'" do
  it_behaves_like :array_pack_basic, 'A'
  it_behaves_like :array_pack_basic_non_float, 'A'
  it_behaves_like :array_pack_no_platform, 'A'
  it_behaves_like :array_pack_string, 'A'
  it_behaves_like :array_pack_taint, 'A'

  it "calls #to_str to convert an Object to a String" do
    obj = mock("pack A string")
    obj.should_receive(:to_str).and_return("``abcdef")
    [obj].pack("A*").should == "``abcdef"
  end

  it "will not implicitly convert a number to a string" do
    -> { [0].pack('A') }.should raise_error(TypeError)
    -> { [0].pack('a') }.should raise_error(TypeError)
  end

  it "adds all the bytes to the output when passed the '*' modifier" do
    ["abc"].pack("A*").should == "abc"
  end

  it "pads the output with spaces when the count exceeds the size of the String" do
    ["abc"].pack("A6").should == "abc   "
  end

  it "adds a space when the value is nil" do
    [nil].pack("A").should == " "
  end

  it "pads the output with spaces when the value is nil" do
    [nil].pack("A3").should == "   "
  end

  it "does not pad with spaces when passed the '*' modifier and the value is nil" do
    [nil].pack("A*").should == ""
  end
end

describe "Array#pack with format 'a'" do
  it_behaves_like :array_pack_basic, 'a'
  it_behaves_like :array_pack_basic_non_float, 'a'
  it_behaves_like :array_pack_no_platform, 'a'
  it_behaves_like :array_pack_string, 'a'
  it_behaves_like :array_pack_taint, 'a'

  it "adds all the bytes to the output when passed the '*' modifier" do
    ["abc"].pack("a*").should == "abc"
  end

  it "pads the output with NULL bytes when the count exceeds the size of the String" do
    ["abc"].pack("a6").should == "abc\x00\x00\x00"
  end

  it "adds a NULL byte when the value is nil" do
    [nil].pack("a").should == "\x00"
  end

  it "pads the output with NULL bytes when the value is nil" do
    [nil].pack("a3").should == "\x00\x00\x00"
  end

  it "does not pad with NULL bytes when passed the '*' modifier and the value is nil" do
    [nil].pack("a*").should == ""
  end
end
