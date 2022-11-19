require 'faraday'
require 'faraday/retry'
require 'json'
require 'pp'
require 'dotenv/load'

$api_connection = Faraday.new(
  url: 'https://apis.lifeweek.com.cn',
  params: {
    equipId: ENV['EQUIP_ID'],
    _ver: '16.1',
    apiVer: '9.4.0',
    _plf: 'iphone',
    appVer: '9.4.0',
    mac: '02:00:00:00:00:00',
    _net: '4G',
    _os: 'ios',
    ticket: ENV['TICKET'],
  },
  headers: {
    'User-Agent': 'zhongdu/9.4.0 (iPad; iOS 16.1; Scale/2.00)',
  }
) do |f|
  f.request :retry
end

$app_connection = Faraday.new(
  url: 'http://ny.zdline.cn',
  params: {
    ticket: ENV['TICKET'],
  },
  headers: {
    'User-Agent': 'zhongdu/9.4.0 (iPad; iOS 16.1; Scale/2.00)',
  }
) do |f|
  f.request :retry
end

def list_json_location
  "raw-data/list.json"
end

def issue_json_location(issue_id)
  "raw-data/issues/#{issue_id}.json"
end

def issue_location(issue_id)
  "raw-data/issues/#{issue_id}"
end

def json_file_downloaded?(path)
  File.exist?(path) &&
  !File.zero?(path)
end

def parse_json_file(path)
  file = File.read(path)
  JSON.parse(file)
end

def fetch_list
  response = $api_connection.get('/api/magazine/periodicalV1', {
    categoryId: 0,
    lineType: 1,
    magazineId: 1,
    pgNo: 1,
    rowNum: 5000,
    year: 0
  })

  File.write('raw-data/list.json', response.body)
end

def list_parser
  data = parse_json_file(list_json_location())

  data['model']['list'].each { |issue| puts "bundle exec ruby download_issue.rb #{issue['id']}" }
end

def fetch_issue(issue_id)
  unless json_file_downloaded?(issue_json_location(issue_id))
    response = $api_connection.get('/api/magazine/chapterList', {
      id: issue_id,
    })

    File.write(issue_json_location(issue_id), response.body)
  end
end

def parse_issue(issue_id)
  data = parse_json_file(issue_json_location(issue_id))

  FileUtils.mkdir_p issue_location(issue_id)

  article_ids = data['model']['list'].flat_map do |lanmu|
    # puts "#{lanmu['lanmuId']} #{lanmu['lanmu']}"
    lanmu['list'].map do |article|
      # puts "#{article['id']}: #{article['title']}"
      article['id']
    end
  end

  article_ids.each do |article_id|
    brief_json = "#{issue_location(issue_id)}/#{article_id}_brief.json"
    detail_json = "#{issue_location(issue_id)}/#{article_id}_detail.json"

    unless json_file_downloaded?(brief_json) && json_file_downloaded?(detail_json)
      puts article_id

      response = $api_connection.get('/api/appDistribution/distributionPoster', {
        artId: article_id
      })

      File.write(brief_json, response.body)

      response = $app_connection.get('/app/scribePosition', {
        artId: article_id
      })

      File.write(detail_json, response.body)
    end
  end

  # pp data
end

# issue_id = 1212
# fetch_issue(issue_id)
# parse_issue(issue_id)

# list_parser
