tokyometroapp-samplecode
========================

本リポジトリは、東京メトロ オープンデータサイト 開発サイトの[サンプルコード](https://developer.tokyometroapp.jp/samplecode)に対して、アクセストークンを外部ファイルに退避する変更を加えたものです。

## Require
- ruby 2.1.2
- [東京メトロのオープンデータ活用コンテスト](http://tokyometro10th.jp/future/opendata/index.html)のアカウントと、アカウントに紐づくアクセストークン

## Usage
サンプル１とサンプル２が、それぞれsample1、sample2ディレクトリにあります。

ここではサンプル１を利用する例を記載します。なお、サンプル２もだいたい同じです。

- ソースのダウンロード
```
git clone git@github.com:betahikaru/tokyometroapp-samplecode.git
cd tokyometroapp-samplecode
```

- .envファイルを作成し、自分のトークンを設定
```
cd sample1
cp .env.sample .env
vi .env
METRO_ACCESS_TOKEN=YOUR_ACCESS_TOKEN_VALUE
```

- gemをインストールし、app.rbを実行
```
bundle install --path vendor/bundle
bundle exec ruby app.rb
```

- http://localhost:4567 にアクセス

## License
[東京メトロオープンデータ活用コンテスト用公共交通データAPI利用許諾規約](https://developer.tokyometroapp.jp/terms.html)を参照。
