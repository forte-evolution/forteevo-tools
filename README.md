# forteevo-tools
shared library copy tool

# autocopy.sh
プログラムをスタンドアロンで動作できるように共有ライブラリをコピーするスクリプトです。

プログラムをchrootやDockerのコンテナで閉じ込めて動作させたい場合に使えると思います。

たいしたスクリプトではない割に、動きがわかりにくいので下の「基本的な使い方」で雰囲気をつかんでください。
zshなのは普段のシェルがそうなのと、連想配列使いたかったからです。bashでも連想配列いけるらしいので、書き直すかも。

>静的リンクがベストだと思いますが、ソース探して取得してビルド方法調べて、、というステップが少々大変だったので、
>開発環境のlibコピーすればとりあえず要件満たせるし、、ということで作成。
>まだやりたいこと全部かけてないけど、とりあえず、だいたい動くので公開。

## 基本的な使い方

### 動作概要


1. $ `./autocopy.sh command1 command2 command3 command4`
2. $ `ls -l`
      output/
3. $ `cd output`
4. $ `ls -l`
     - Dockerfile
     - files/
     - files.tar.gz
5. $ `docker build -t youroriginalcontainer .`
6. happy :D


### (例) sh のみ動作する Docker コンテナを作る

このスクリプトを作るきっかけ。sh(dash)すらlibc使ってて。

1. autocopy.sh 実行
   - $ `./autocopy.sh sh`
2. 出力ディレクトリへ cd
   - $ `cd output`
3. 内容確認
   - $ `tree`
   いろいろコピーできているはず
4. Docker container build
   これがやりたかった
   - $ `docker build -t yourcontainer .`
5. Docker Run!
   - $ `docker run -it --rm yourcontainer /bin/sh`

なお、Dockerは/bin/shをデフォルトで使用しているみたいなので、/bin/shは必ずコピーされます。


### (例) sh, bash, ls, cat が使える Docker コンテナを作る

autocopy.sh の引数は複数指定できます。重複するライブラリも大丈夫。

1. autocopy.sh bash ls cat
2. 以下略


### 課題

共有ライブラリの探索は ldd を使ってます。これで検出できない共有ライブラリは未対応。どうやれば。。
動的ロードされるライブラリっぽい。

具体的には、zshがダメ。zsh/zleというライブラリを必要としますが、lddで出ないからダメ。。
zsh依存のコード(連想配列)をawk化して、このsh自体はdashで動くようにしました。
