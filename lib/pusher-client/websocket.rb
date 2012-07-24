require 'rubygems'
require 'socket'
require 'libwebsocket'

module PusherClient
  class WebSocket

    def initialize(url, encrypted = false, params = {})
      @hs ||= LibWebSocket::OpeningHandshake::Client.new(:url => url, :version => params[:version])
      @frame ||= LibWebSocket::Frame.new

      tcp_socket = TCPSocket.new(@hs.url.host, @hs.url.port || 80)
      if encrypted
        @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket)
        @socket.sync_close = true
        @socket.connect
      else
        @socket = tcp_socket
      end
      @socket.write(@hs.to_s)
      @socket.write("\r\n\r\n")
      @socket.flush

      loop do
        data = @socket.gets
        next if data.nil?

        result = @hs.parse(data)

        raise @hs.error unless result

        if @hs.done?
          @handshaked = true
          break
        end
      end
    end

    def send(data)
      raise "no handshake!" unless @handshaked

      data = @frame.new(data).to_s
      @socket.write data
      @socket.flush
    end

    def receive
      raise "no handshake!" unless @handshaked

      data = @socket.gets("\xff")
      @frame.append(data)

      messages = []
      while message = @frame.next
        messages << message
      end
      messages
    end

    def socket
      @socket
    end

    def close
      @socket.close
    end

  end
end


