require 'openssl'
require 'socket'
require 'timeout'

module APNS

MAX_32_BIT =  2_147_483_647

class Connection
  attr_accessor :error_handler

  def initialize(pem: ,
                 pass: nil,
                 host: 'gateway.sandbox.push.apple.com',
                 port: 2195,
                 buffer_size: 64 * 1024)
    @notifications = InfiniteArray.new(buffer_size: buffer_size)
    @pem =  pem
    @pass = pass
    @host = host
    @port = port

    @sock, @ssl = open_connection
    ObjectSpace.define_finalizer(self, self.class.finalize(@sock, @ssl))
  end
  def self.finalize sock, ssl
    proc {
      ssl.close
      sock.close
    }
  end

  def push ns
    # The notification identifier is set to 4 bytes in the APNS protocol. Thus,
    # upon hitting this limit, read for failures and restart the counting again.
    if @notifications.size + ns.size > MAX_32_BIT - 10
      code, failed_id = read_failure_info(timeout: 3)
      if failed_id
        ns = @notifications.items_from(failed_id+1) + ns
        reopen_connection
        @error_handler.call(code, @notifications.item_at(failed_id))
      end

      @notifications.clear
    end

    ns.each{ |n|
      n.message_identifier = [@notifications.size].pack('N')
      @notifications.push(n)
    }
    write ns
  end


  private

  def write ns
    packed = pack_notifications(ns)
    @ssl.write(packed)
  rescue Errno::EPIPE, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    code, failed_id = read_failure_info(timeout: 30)
    reopen_connection
    return unless failed_id # there's nothing we can do

    @error_handler.call(code, @notifications.item_at(failed_id))

    @notifications.delete_where_index_less_than(failed_id+1)
    ns = @notifications.items_from(failed_id+1)
    retry
  end

  def pack_notifications notifications
    bytes = ''

    notifications.each do |n|
      # Each notification frame consists of
      # 1. (e.g. protocol version) 2 (unsigned char [1 byte]) 
      # 2. size of the full frame (unsigend int [4 byte], big endian)
      pn = n.packaged_notification
      bytes << ([2, pn.bytesize].pack('CN') + pn)
    end

    bytes
  end

  def read_failure_info(timeout:)
    tuple = Timeout::timeout(timeout){ @ssl.read(6) }
    _, code, failed_id = tuple.unpack("ccN")
    [code, failed_id]
  rescue Timeout::Error
  end

  def reopen_connection
    @ssl.close
    @sock.close
    @sock, @ssl = open_connection
  end

  def open_connection
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(@pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(@pem), @pass)

    sock         = TCPSocket.new(@host, @port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end

  # Override inspect since we do not want to print out the entire @notifications,
  # whose size might be over tens of thousands
  def inspect
    puts "#<#{self.class}:#{'0x%014x' % object_id} @pem=#{@pem} @pass=#{@pass} @host=#{@host} @port=#{@port} @error_handler=#{@error_handler}>"
  end

end
end
