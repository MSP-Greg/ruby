require_relative '../spec_helper'
require_relative '../fixtures/classes'

describe 'BasicSocket#recvmsg_nonblock' do
  SocketSpecs.each_ip_protocol do |family, ip_address|
    describe 'using a disconnected socket' do
      before do
        @client = Socket.new(family, :DGRAM)
        @server = Socket.new(family, :DGRAM)
      end

      after do
        @client.close
        @server.close
      end

      platform_is_not :windows do
        describe 'using an unbound socket' do
          it 'raises an exception extending IO::WaitReadable' do
            -> { @server.recvmsg_nonblock }.should raise_error(IO::WaitReadable)
          end
        end
      end

      describe 'using a bound socket' do
        before do
          @server.bind(Socket.sockaddr_in(0, ip_address))
        end

        describe 'without any data available' do
          it 'raises an exception extending IO::WaitReadable' do
            -> { @server.recvmsg_nonblock }.should raise_error(IO::WaitReadable)
          end

          it 'returns :wait_readable with exception: false' do
            @server.recvmsg_nonblock(exception: false).should == :wait_readable
          end
        end

        describe 'with data available' do
          before do
            @client.connect(@server.getsockname)

            @client.write('hello')

            IO.select([@server], nil, nil, 5)
          end

          it 'returns an Array containing the data, an Addrinfo and the flags' do
            @server.recvmsg_nonblock.should be_an_instance_of(Array)
          end

          describe 'without a maximum message length' do
            it 'reads all the available data' do
              @server.recvmsg_nonblock[0].should == 'hello'
            end
          end

          describe 'with a maximum message length' do
            platform_is_not :windows do
              it 'reads up to the maximum amount of bytes' do
                @server.recvmsg_nonblock(2)[0].should == 'he'
              end
            end
          end

          describe 'the returned Array' do
            before do
              @array = @server.recvmsg_nonblock
            end

            it 'stores the message at index 0' do
              @array[0].should == 'hello'
            end

            it 'stores an Addrinfo at index 1' do
              @array[1].should be_an_instance_of(Addrinfo)
            end

            platform_is_not :windows do
              it 'stores the flags at index 2' do
                @array[2].should be_kind_of(Integer)
              end
            end

            describe 'the returned Addrinfo' do
              before do
                @addr = @array[1]
              end

              it 'uses the IP address of the client' do
                @addr.ip_address.should == @client.local_address.ip_address
              end

              it 'uses the correct address family' do
                @addr.afamily.should == family
              end

              it 'uses the correct protocol family' do
                @addr.pfamily.should == family
              end

              it 'uses the correct socket type' do
                @addr.socktype.should == Socket::SOCK_DGRAM
              end

              it 'uses the port number of the client' do
                @addr.ip_port.should == @client.local_address.ip_port
              end
            end
          end
        end
      end
    end

    platform_is_not :windows do
      describe 'using a connected but not bound socket' do
        before do
          @server = Socket.new(family, :STREAM)
        end

        after do
          @server.close
        end

        it "raises Errno::ENOTCONN" do
          -> { @server.recvmsg_nonblock }.should raise_error(Errno::ENOTCONN)
          -> { @server.recvmsg_nonblock(exception: false) }.should raise_error(Errno::ENOTCONN)
        end
      end

      describe 'using a connected socket' do
        before do
          @client = Socket.new(family, :STREAM)
          @server = Socket.new(family, :STREAM)

          @server.bind(Socket.sockaddr_in(0, ip_address))
          @server.listen(1)

          @client.connect(@server.getsockname)
        end

        after do
          @client.close
          @server.close
        end

        describe 'without any data available' do
          it 'raises IO::WaitReadable' do
            -> {
              socket, _ = @server.accept
              begin
                socket.recvmsg_nonblock
              ensure
                socket.close
              end
            }.should raise_error(IO::WaitReadable)
          end
        end

        describe 'with data available' do
          before do
            @client.write('hello')

            @socket, _ = @server.accept
            IO.select([@socket])
          end

          after do
            @socket.close
          end

          it 'returns an Array containing the data, an Addrinfo and the flags' do
            @socket.recvmsg_nonblock.should be_an_instance_of(Array)
          end

          describe 'the returned Array' do
            before do
              @array = @socket.recvmsg_nonblock
            end

            it 'stores the message at index 0' do
              @array[0].should == 'hello'
            end

            it 'stores an Addrinfo at index 1' do
              @array[1].should be_an_instance_of(Addrinfo)
            end

            it 'stores the flags at index 2' do
              @array[2].should be_kind_of(Integer)
            end

            describe 'the returned Addrinfo' do
              before do
                @addr = @array[1]
              end

              it 'raises when receiving the ip_address message' do
                -> { @addr.ip_address }.should raise_error(SocketError)
              end

              it 'uses the correct address family' do
                @addr.afamily.should == Socket::AF_UNSPEC
              end

              it 'uses 0 for the protocol family' do
                @addr.pfamily.should == 0
              end

              it 'uses the correct socket type' do
                @addr.socktype.should == Socket::SOCK_STREAM
              end

              it 'raises when receiving the ip_port message' do
                -> { @addr.ip_port }.should raise_error(SocketError)
              end
            end
          end
        end
      end
    end
  end
end

describe 'BasicSocket#recvmsg_nonblock' do
  context "when recvfrom(2) returns 0 (if no messages are available to be received and the peer has performed an orderly shutdown)" do
    describe "stream socket" do
      before :each do
        @server = TCPServer.new('127.0.0.1', 0)
        @port = @server.addr[1]
      end

      after :each do
        @server.close unless @server.closed?
      end

      ruby_version_is ""..."3.3" do
        platform_is_not :windows do # #recvmsg_nonblock() raises 'Errno::EINVAL: Invalid argument - recvmsg(2)'
          it "returns an empty String as received data on a closed stream socket" do
            ready = false

            t = Thread.new do
              client = @server.accept

              Thread.pass while !ready
              begin
                client.recvmsg_nonblock(10)
              rescue IO::EAGAINWaitReadable
                retry
              end
            ensure
              client.close if client
            end

            Thread.pass while t.status and t.status != "sleep"
            t.status.should_not be_nil

            socket = TCPSocket.new('127.0.0.1', @port)
            socket.close
            ready = true

            t.value.should.is_a? Array
            t.value[0].should == ""
          end
        end
      end

      ruby_version_is "3.3" do
        platform_is_not :windows do
          it "returns nil on a closed stream socket" do
            ready = false

            t = Thread.new do
              client = @server.accept

              Thread.pass while !ready
              begin
                client.recvmsg_nonblock(10)
              rescue IO::EAGAINWaitReadable
                retry
              end
            ensure
              client.close if client
            end

            Thread.pass while t.status and t.status != "sleep"
            t.status.should_not be_nil

            socket = TCPSocket.new('127.0.0.1', @port)
            socket.close
            ready = true

            t.value.should be_nil
          end
        end
      end
    end
  end
end
