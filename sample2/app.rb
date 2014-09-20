# -*- coding: utf-8 -*-
require 'dotenv'
require 'httpclient'
require 'sinatra'
require 'yaml' # YAMLを扱うライブラリ
require 'date' # 時刻ライブラリ
require 'json' # JSONを扱うライブラリ

# 環境変数
Dotenv.load

API_ENDPOINT   = 'https://api.tokyometroapp.jp/api/v2/'
DATAPOINTS_URL = API_ENDPOINT + "datapoints"
PLACES_URL     = API_ENDPOINT + "places"
ACCESS_TOKEN   = ENV['METRO_ACCESS_TOKEN']
PLACES_RADIUS  = 300 # Places APIでの検索半径(m)

# 駅リストの読み込み
STATION_LIST   = YAML.load_file('sample2/stationList.yaml')

# HTTP GET リクエストに対する処理です。
get '/' do
  # views/index.erb を表示します。
  erb :index
end

# station_nameに入力された駅名から、
# ファイルに書かれた駅情報を検索し、結果のリストを返します。
# ファイルに書かれた駅情報を探す代わりに、
# odpt.Station をAPI経由で取得することも可能です。
def get_stations(station_name)
  # 駅名をマッチする際には、注意点があります。
  result = []
  STATION_LIST.each do |station|
    result << station if station_name==station["name"]
  end
  result
end

# odpt.Station形式の駅名から、
# 表示用の駅名を取得します。
def get_station_name(odpt_station_name)
  STATION_LIST.each do |station|
    return station["name"] if odpt_station_name==station["odpt_name"]
  end
end

# HTTP POST リクエストに対する処理です。
post '/' do
  # 受け取った緯度経度周辺にある地物（駅）を、
  # places API を利用して検索しています。
  http_client = HTTPClient.new
  response = http_client.get PLACES_URL,
    { "rdf:type"=>"mlit:Station",
      "lat"     =>params[:lat],
      "lon"     =>params[:lon],
      "radius"  => PLACES_RADIUS,
      "acl:consumerKey"=>ACCESS_TOKEN }

  # 検索結果のうち、東京メトロの駅のみを抽出しています。
  near_stations = []
  JSON.parse( response.body ).each do |station|
    if station["mlit:operatorName"] == "東京地下鉄"
      near_stations << station
    end
  end
puts near_stations

  # 取得できた駅名は自然言語で格納されているため、
  # 時刻表検索のために、odpt.Station形式も保持したデータを取得します
  # 駅が複数路線に属している場合は、全て抽出します
  # また、mlit:Stationで取得できた路線名は時刻表取得に向かないため、
  # 駅名をユニークにして、駅名をキーにodpt:Station形式の駅名を取得します。
  odpt_station_list = []
  near_stations.uniq{|station| station["mlit:stationName"]}.each do |station|
    odpt_station_list.concat(get_stations(station["mlit:stationName"]))
  end

  # タイムゾーンを日本時間に設定します
  now = DateTime.now.new_offset(Rational(9, 24))
  # 結果は @results に格納し、show.erb から参照可能にします。
  @results = []
  # APIへ接続するためのクライアントを作成します。
  http_client = HTTPClient.new
  # 駅名それぞれについて、APIにアクセスして時刻表を取得します。
  odpt_station_list.each do |station|
    response = http_client.get DATAPOINTS_URL,
      {"rdf:type"=>"odpt:StationTimetable",
       "odpt:station"=>station["odpt_name"],
       "acl:consumerKey"=>ACCESS_TOKEN}
    # 時刻表は方面毎に存在するため、それぞれについて処理します
    JSON.parse(response.body).each do |station_timetable|
      # 「今日」の曜日に応じて、該当する時刻表を選択します
      # ここでは、平日と土日のチェックのみ行います。
      # 祝日の判定は、祝日の判定を行うgemがいくつか公開されていますので、
      # そちらをご活用ください
      timetable = case now.wday
                  when 0
                    station_timetable["odpt:holidays"]
                  when 6
                    station_timetable["odpt:saturdays"]
                  else
                    station_timetable["odpt:weekdays"]
                  end
      # 時刻表の中から、現在時刻以降の発車予定時刻を探します
      timetable.each do |time|
        # 「hh:mm」形式(hは時間、mは分を表す)で格納されている文字列から、
        # 時間、分をそれぞれ整数型で取得します。
        hour, min = time["odpt:departureTime"].split(":").map{|num| num.to_i}
        # 時刻の比較を簡単にするため、DateTime型のオブジェクトを作成します。
        timetable_datetime = DateTime.new(now.year, now.month, now.day, hour, min, 0, "+9")
        # 時刻表に掲載されている時間が2時以下の場合は、
        # 日付が翌日となっているため、日付を1日進めます。
        timetable_datetime.next_day if hour <= 2
        # 時刻表の時刻が現在時刻以前であれば、読み飛ばします。
        next if now > timetable_datetime
        # 時刻表の時刻が現在時刻より未来である場合は、
        # 結果に、駅名、路線名、時刻、行き先を保存し、次の方面の処理を行います。
        @results << {"name"=>station["name"],
                     "line_name"=>station["line"],
                     "time"=>time["odpt:departureTime"],
                     "dest"=>get_station_name(time["odpt:destinationStation"])}
        break
      end
    end
  end
  # show.erb を表示します。
  erb :show
end
