require 'net/http'
require 'logger'
require 'benchmark'
require 'yaml'

begin
  config = YAML::load(File.open(ARGV.first || 'config.yml'))

  log = Logger.new(config['log_file'])
  log.datetime_format = "%Y-%m-%d %H:%M:%S"
  log.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime} #{severity} #{msg}\n"
  end
  urls = File.open(config['urls_file'])
  urls.each do |url|
    url.strip!
    uri = URI.parse(url)
    response = nil
    time = Benchmark.measure do
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        response = http.request request
      end
    end
    bm = "%.3f" % time.real
    msg = "#{response.code} #{bm}s #{url}"
    if response.code == '200' and time.real < config['timeout_level']
      log.info(msg)
    else
      log.error(msg)
      system %(echo '' | mail -s "#{uri.host} #{response.code} #{bm}" #{config['alert_mail']})
    end
  end
  log.close
rescue => err
  log.fatal(err)
end
