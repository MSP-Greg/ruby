# frozen_string_literal: true
=begin
This file is generated by the bin/template script and should not be
modified manually. See templates/lib/yarp/serialize.rb.erb
if you are looking to modify the template
=end

require "stringio"

module YARP
  module Serialize
    def self.load(input, serialized)
      io = StringIO.new(serialized)
      io.set_encoding(Encoding::BINARY)

      Loader.new(input, serialized, io).load
    end

    class Loader
      attr_reader :encoding, :input, :serialized, :io
      attr_reader :constant_pool_offset, :constant_pool, :source

      def initialize(input, serialized, io)
        @encoding = Encoding::UTF_8

        @input = input.dup
        @serialized = serialized
        @io = io

        @constant_pool_offset = nil
        @constant_pool = nil

        offsets = [0]
        input.b.scan("\n") { offsets << $~.end(0) }
        @source = Source.new(input, offsets)
      end

      def load
        io.read(4) => "YARP"
        io.read(3).unpack("C3") => [0, 4, 0]

        @encoding = Encoding.find(io.read(load_varint))
        @input = input.force_encoding(@encoding).freeze

        @constant_pool_offset = io.read(4).unpack1("L")
        @constant_pool = Array.new(load_varint, nil)

        load_node
      end

      private

      # variable-length integer using https://en.wikipedia.org/wiki/LEB128
      # This is also what protobuf uses: https://protobuf.dev/programming-guides/encoding/#varints
      def load_varint
        n = io.getbyte
        if n < 128
          n
        else
          n -= 128
          shift = 0
          while (b = io.getbyte) >= 128
            n += (b - 128) << (shift += 7)
          end
          n + (b << (shift + 7))
        end
      end

      def load_serialized_length
        io.read(4).unpack1("L")
      end

      def load_optional_node
        if io.getbyte != 0
          io.pos -= 1
          load_node
        end
      end

      def load_string
        io.read(load_varint).force_encoding(encoding)
      end

      def load_location
        Location.new(source, load_varint, load_varint)
      end

      def load_optional_location
        load_location if io.getbyte != 0
      end

      def load_constant
        index = load_varint - 1
        constant = constant_pool[index]

        unless constant
          offset = constant_pool_offset + index * 8

          start = serialized.unpack1("L", offset: offset)
          length = serialized.unpack1("L", offset: offset + 4)

          constant = input.byteslice(start, length).to_sym
          constant_pool[index] = constant
        end

        constant
      end

      def load_node
        type = io.getbyte
        location = load_location

        case type
        when 1 then
          AliasNode.new(load_node, load_node, load_location, location)
        when 2 then
          AlternationPatternNode.new(load_node, load_node, load_location, location)
        when 3 then
          AndNode.new(load_node, load_node, load_location, location)
        when 4 then
          ArgumentsNode.new(Array.new(load_varint) { load_node }, location)
        when 5 then
          ArrayNode.new(Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 6 then
          ArrayPatternNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 7 then
          AssocNode.new(load_node, load_optional_node, load_optional_location, location)
        when 8 then
          AssocSplatNode.new(load_optional_node, load_location, location)
        when 9 then
          BackReferenceReadNode.new(location)
        when 10 then
          BeginNode.new(load_optional_location, load_optional_node, load_optional_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 11 then
          BlockArgumentNode.new(load_optional_node, load_location, location)
        when 12 then
          BlockNode.new(Array.new(load_varint) { load_constant }, load_optional_node, load_optional_node, load_location, load_location, location)
        when 13 then
          BlockParameterNode.new(load_optional_location, load_location, location)
        when 14 then
          BlockParametersNode.new(load_optional_node, Array.new(load_varint) { load_location }, load_optional_location, load_optional_location, location)
        when 15 then
          BreakNode.new(load_optional_node, load_location, location)
        when 16 then
          CallNode.new(load_optional_node, load_optional_location, load_optional_location, load_optional_location, load_optional_node, load_optional_location, load_optional_node, load_varint, load_string, location)
        when 17 then
          CallOperatorAndWriteNode.new(load_node, load_location, load_node, location)
        when 18 then
          CallOperatorOrWriteNode.new(load_node, load_node, load_location, location)
        when 19 then
          CallOperatorWriteNode.new(load_node, load_location, load_node, load_constant, location)
        when 20 then
          CapturePatternNode.new(load_node, load_node, load_location, location)
        when 21 then
          CaseNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, load_location, load_location, location)
        when 22 then
          ClassNode.new(Array.new(load_varint) { load_constant }, load_location, load_node, load_optional_location, load_optional_node, load_optional_node, load_location, location)
        when 23 then
          ClassVariableOperatorAndWriteNode.new(load_location, load_location, load_node, location)
        when 24 then
          ClassVariableOperatorOrWriteNode.new(load_location, load_location, load_node, location)
        when 25 then
          ClassVariableOperatorWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 26 then
          ClassVariableReadNode.new(location)
        when 27 then
          ClassVariableWriteNode.new(load_location, load_optional_node, load_optional_location, location)
        when 28 then
          ConstantOperatorAndWriteNode.new(load_location, load_location, load_node, location)
        when 29 then
          ConstantOperatorOrWriteNode.new(load_location, load_location, load_node, location)
        when 30 then
          ConstantOperatorWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 31 then
          ConstantPathNode.new(load_optional_node, load_node, load_location, location)
        when 32 then
          ConstantPathOperatorAndWriteNode.new(load_node, load_location, load_node, location)
        when 33 then
          ConstantPathOperatorOrWriteNode.new(load_node, load_location, load_node, location)
        when 34 then
          ConstantPathOperatorWriteNode.new(load_node, load_location, load_node, load_constant, location)
        when 35 then
          ConstantPathWriteNode.new(load_node, load_optional_location, load_optional_node, location)
        when 36 then
          ConstantReadNode.new(location)
        when 37 then
          load_serialized_length
          DefNode.new(load_location, load_optional_node, load_optional_node, load_optional_node, Array.new(load_varint) { load_constant }, load_location, load_optional_location, load_optional_location, load_optional_location, load_optional_location, load_optional_location, location)
        when 38 then
          DefinedNode.new(load_optional_location, load_node, load_optional_location, load_location, location)
        when 39 then
          ElseNode.new(load_location, load_optional_node, load_optional_location, location)
        when 40 then
          EmbeddedStatementsNode.new(load_location, load_optional_node, load_location, location)
        when 41 then
          EmbeddedVariableNode.new(load_location, load_node, location)
        when 42 then
          EnsureNode.new(load_location, load_optional_node, load_location, location)
        when 43 then
          FalseNode.new(location)
        when 44 then
          FindPatternNode.new(load_optional_node, load_node, Array.new(load_varint) { load_node }, load_node, load_optional_location, load_optional_location, location)
        when 45 then
          FloatNode.new(location)
        when 46 then
          ForNode.new(load_node, load_node, load_optional_node, load_location, load_location, load_optional_location, load_location, location)
        when 47 then
          ForwardingArgumentsNode.new(location)
        when 48 then
          ForwardingParameterNode.new(location)
        when 49 then
          ForwardingSuperNode.new(load_optional_node, location)
        when 50 then
          GlobalVariableOperatorAndWriteNode.new(load_location, load_location, load_node, location)
        when 51 then
          GlobalVariableOperatorOrWriteNode.new(load_location, load_location, load_node, location)
        when 52 then
          GlobalVariableOperatorWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 53 then
          GlobalVariableReadNode.new(location)
        when 54 then
          GlobalVariableWriteNode.new(load_location, load_optional_location, load_optional_node, location)
        when 55 then
          HashNode.new(load_location, Array.new(load_varint) { load_node }, load_location, location)
        when 56 then
          HashPatternNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, load_optional_location, load_optional_location, location)
        when 57 then
          IfNode.new(load_optional_location, load_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 58 then
          ImaginaryNode.new(load_node, location)
        when 59 then
          InNode.new(load_node, load_optional_node, load_location, load_optional_location, location)
        when 60 then
          InstanceVariableOperatorAndWriteNode.new(load_location, load_location, load_node, location)
        when 61 then
          InstanceVariableOperatorOrWriteNode.new(load_location, load_location, load_node, location)
        when 62 then
          InstanceVariableOperatorWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 63 then
          InstanceVariableReadNode.new(location)
        when 64 then
          InstanceVariableWriteNode.new(load_location, load_optional_node, load_optional_location, location)
        when 65 then
          IntegerNode.new(location)
        when 66 then
          InterpolatedRegularExpressionNode.new(load_location, Array.new(load_varint) { load_node }, load_location, load_varint, location)
        when 67 then
          InterpolatedStringNode.new(load_optional_location, Array.new(load_varint) { load_node }, load_optional_location, location)
        when 68 then
          InterpolatedSymbolNode.new(load_optional_location, Array.new(load_varint) { load_node }, load_optional_location, location)
        when 69 then
          InterpolatedXStringNode.new(load_location, Array.new(load_varint) { load_node }, load_location, location)
        when 70 then
          KeywordHashNode.new(Array.new(load_varint) { load_node }, location)
        when 71 then
          KeywordParameterNode.new(load_location, load_optional_node, location)
        when 72 then
          KeywordRestParameterNode.new(load_location, load_optional_location, location)
        when 73 then
          LambdaNode.new(Array.new(load_varint) { load_constant }, load_location, load_optional_node, load_optional_node, location)
        when 74 then
          LocalVariableOperatorAndWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 75 then
          LocalVariableOperatorOrWriteNode.new(load_location, load_location, load_node, load_constant, location)
        when 76 then
          LocalVariableOperatorWriteNode.new(load_location, load_location, load_node, load_constant, load_constant, location)
        when 77 then
          LocalVariableReadNode.new(load_constant, load_varint, location)
        when 78 then
          LocalVariableWriteNode.new(load_constant, load_varint, load_optional_node, load_location, load_optional_location, location)
        when 79 then
          MatchPredicateNode.new(load_node, load_node, load_location, location)
        when 80 then
          MatchRequiredNode.new(load_node, load_node, load_location, location)
        when 81 then
          MissingNode.new(location)
        when 82 then
          ModuleNode.new(Array.new(load_varint) { load_constant }, load_location, load_node, load_optional_node, load_location, location)
        when 83 then
          MultiWriteNode.new(Array.new(load_varint) { load_node }, load_optional_location, load_optional_node, load_optional_location, load_optional_location, location)
        when 84 then
          NextNode.new(load_optional_node, load_location, location)
        when 85 then
          NilNode.new(location)
        when 86 then
          NoKeywordsParameterNode.new(load_location, load_location, location)
        when 87 then
          NumberedReferenceReadNode.new(location)
        when 88 then
          OptionalParameterNode.new(load_constant, load_location, load_location, load_node, location)
        when 89 then
          OrNode.new(load_node, load_node, load_location, location)
        when 90 then
          ParametersNode.new(Array.new(load_varint) { load_node }, Array.new(load_varint) { load_node }, Array.new(load_varint) { load_node }, load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, load_optional_node, location)
        when 91 then
          ParenthesesNode.new(load_optional_node, load_location, load_location, location)
        when 92 then
          PinnedExpressionNode.new(load_node, load_location, load_location, load_location, location)
        when 93 then
          PinnedVariableNode.new(load_node, load_location, location)
        when 94 then
          PostExecutionNode.new(load_optional_node, load_location, load_location, load_location, location)
        when 95 then
          PreExecutionNode.new(load_optional_node, load_location, load_location, load_location, location)
        when 96 then
          ProgramNode.new(Array.new(load_varint) { load_constant }, load_node, location)
        when 97 then
          RangeNode.new(load_optional_node, load_optional_node, load_location, load_varint, location)
        when 98 then
          RationalNode.new(load_node, location)
        when 99 then
          RedoNode.new(location)
        when 100 then
          RegularExpressionNode.new(load_location, load_location, load_location, load_string, load_varint, location)
        when 101 then
          RequiredDestructuredParameterNode.new(Array.new(load_varint) { load_node }, load_location, load_location, location)
        when 102 then
          RequiredParameterNode.new(load_constant, location)
        when 103 then
          RescueModifierNode.new(load_node, load_location, load_node, location)
        when 104 then
          RescueNode.new(load_location, Array.new(load_varint) { load_node }, load_optional_location, load_optional_node, load_optional_node, load_optional_node, location)
        when 105 then
          RestParameterNode.new(load_location, load_optional_location, location)
        when 106 then
          RetryNode.new(location)
        when 107 then
          ReturnNode.new(load_location, load_optional_node, location)
        when 108 then
          SelfNode.new(location)
        when 109 then
          SingletonClassNode.new(Array.new(load_varint) { load_constant }, load_location, load_location, load_node, load_optional_node, load_location, location)
        when 110 then
          SourceEncodingNode.new(location)
        when 111 then
          SourceFileNode.new(load_string, location)
        when 112 then
          SourceLineNode.new(location)
        when 113 then
          SplatNode.new(load_location, load_optional_node, location)
        when 114 then
          StatementsNode.new(Array.new(load_varint) { load_node }, location)
        when 115 then
          StringConcatNode.new(load_node, load_node, location)
        when 116 then
          StringNode.new(load_optional_location, load_location, load_optional_location, load_string, location)
        when 117 then
          SuperNode.new(load_location, load_optional_location, load_optional_node, load_optional_location, load_optional_node, location)
        when 118 then
          SymbolNode.new(load_optional_location, load_location, load_optional_location, load_string, location)
        when 119 then
          TrueNode.new(location)
        when 120 then
          UndefNode.new(Array.new(load_varint) { load_node }, load_location, location)
        when 121 then
          UnlessNode.new(load_location, load_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 122 then
          UntilNode.new(load_location, load_node, load_optional_node, location)
        when 123 then
          WhenNode.new(load_location, Array.new(load_varint) { load_node }, load_optional_node, location)
        when 124 then
          WhileNode.new(load_location, load_node, load_optional_node, location)
        when 125 then
          XStringNode.new(load_location, load_location, load_location, load_string, location)
        when 126 then
          YieldNode.new(load_location, load_optional_location, load_optional_node, load_optional_location, location)
        end
      end
    end
  end
end