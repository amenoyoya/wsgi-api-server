version: "3"

services:
  # nginx web server
  web:
    build: ./docker/web
    links:
      - python # pythonコンテナとリンク
    volumes:
      - ./app:/var/www/app # アプリケーション開発ディレクトリ
      # nginx設定共有
      - ./docker/web/nginx.conf:/etc/nginx/nginx.conf
    command: nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
    environment:
      TZ: Asia/Tokyo
      # VIRTUAL_HOST設定（nginx-proxy）
{{^HOST}}
      CERT_NAME: default # ローカル開発時は自己証明書を使う
      VIRTUAL_HOST: web.local # http://web.local/ => docker://web:80
{{/HOST}}
{{#HOST}}
      VIRTUAL_HOST: {{HOST}} # http://{{HOST}}/ => docker://web:80
      LETSENCRYPT_HOST: {{HOST}}
{{^EMAIL}}
      LETSENCRYPT_EMAIL: admin@{{HOST}}
{{/EMAIL}}
{{#EMAIL}}
      LETSENCRYPT_EMAIL: {{EMAIL}}
{{/EMAIL}}
{{/HOST}}
      VIRTUAL_PORT: 80

  # python app server
  python:
    build:
      context: ./docker/python # ./docker/python/Dockerfile をビルド
      args:
        # Docker実行ユーザIDをビルド時に使用
        UID: $UID
    volumes:
      - ./app:/var/www/app # アプリケーション開発ディレクトリ
    environment:
      TZ: Asia/Tokyo

{{^NOPROXY}}
  # vhostプロキシサーバ
  nginx-proxy:
    image: jwilder/nginx-proxy
    privileged: true # ルート権限
    ports:
      - "80:80" # http
      - "443:443" # https
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - /usr/share/nginx/html
      - /etc/nginx/vhost.d
      - ./docker/certs:/etc/nginx/certs:ro # letsencryptコンテナが ./docker/certs/ に作成したSSL証明書を読む
    environment:
      DHPARAM_GENERATION: "false"
    labels:
      com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy: "true"

  # 無料SSL証明書発行コンテナ
  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /usr/share/nginx/html
      - /etc/nginx/vhost.d
      - ./docker/certs:/etc/nginx/certs:rw # ./docker/certs/ にSSL証明書を書き込めるように rw モードで共有
    depends_on:
      - nginx-proxy # nginx-proxyコンテナの後で起動
    environment:
      NGINX_PROXY_CONTAINER: nginx-proxy
{{/NOPROXY}}
