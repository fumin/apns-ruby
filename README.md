apns-ruby
-----
This gem sends APNS notifications with proper error handling. Most importantly, it does this without all the nonsense other gems provide:
* Storing notifications in a database, and have a separate process consume them. Worse, only a single consumer is ever allowed.
* Opening a new SSL connection for every notification, which typically takes several hundred milliseconds. Imagine how long it would take to send a million notifications.

As of 2015-03-04, this gem has been powering [PicCollage](http://pic-collage.com/) for more than a year, sending more than 500 notifications per second at peak time, only to be limited by the devices database's throughput.

Example usage:
```
pem = path_to_your_pem_file
host = 'gateway.sandbox.push.apple.com' # or 'gateway.push.apple.com' on production
token = a_valid_apns_device_token
conn = APNS::Connection.new(pem: pem, host: host)
conn.error_handler = ->(code, notification) {
  case code
  when 8
    if notification.nil?
      puts "Insufficient buffer size to collect failed notifications, please set a larger buffer size when creating an APNS connection."
      return
    end
    puts "Invalid token: #{notification.device_token}"
    # Handle the invalid token per Apple's docs
  else
    # Consult Apple's docs
  end
}
n1 = APNS::Notification.new(token, alert: 'hello')
ne = APNS::Notification.new('bogustoken', alert: 'error')
n2 = APNS::Notification.new(token, alert: 'world')
conn.push([n1, ne, n2])
# 'Invalid token: bogustoken' is printed out.
# Moreover, we should be receiving each and every successful notification with texts 'hello' and 'world'.
```

A great amount of code in this gem is copied from https://github.com/jpoz/APNS , many thanks to his pioneering work. This work itself is licensed under the MIT license.
