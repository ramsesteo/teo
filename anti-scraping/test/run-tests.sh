#!/usr/bin/env bash
# Yerel test: nginx'i 8080 portunda gecici bir prefix ile calistirir ve kurallari dogrular.
# Kullanim: bash anti-scraping/test/run-tests.sh
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="${TMPDIR:-/tmp}/anti-scraping-test"
rm -rf "$T"; mkdir -p "$T/logs" "$T/www" "$T/conf"
cp "$HERE/nginx/anti-scraping-http.conf" "$T/conf/"
cp "$HERE/web/robots.txt" "$T/www/"
echo '<html><body>ok</body></html>' > "$T/www/index.html"
echo 'body{}' > "$T/www/a.css"

# Server konfigini test icin uyarlayalim: robots root ve loglar gecici dizine, Cloudflare kurali kapali
sed -e "s#/var/log/nginx/honeypot.log#$T/logs/honeypot.log#" \
    -e "s#root /var/www/anti-scraping;#root $T/www;#" \
    -e "s#^if (\$not_cloudflare).*#\# (test: Cloudflare kurali kapali)#" \
    "$HERE/nginx/anti-scraping-server.conf" > "$T/conf/anti-scraping-server.conf"

cat > "$T/conf/nginx.conf" <<NG
pid $T/nginx.pid;
error_log $T/logs/error.log warn;
events { worker_connections 128; }
http {
    access_log $T/logs/access.log combined;
    include $T/conf/anti-scraping-http.conf;
    server {
        listen 127.0.0.1:8080;
        root $T/www;
        include $T/conf/anti-scraping-server.conf;
        location / { limit_req zone=scrape_page burst=20 nodelay; try_files \$uri \$uri/ =404; }
    }
}
NG

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1 -> $2"; PASS=$((PASS+1)); else echo "FAIL  $1 -> beklenen $3, gelen $2"; FAIL=$((FAIL+1)); fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "== nginx -t"; nginx -t -c "$T/conf/nginx.conf" -p "$T" 2>&1 | sed 's/^/   /' || exit 1
nginx -c "$T/conf/nginx.conf" -p "$T"; sleep 0.5
trap 'nginx -s quit -c "$T/conf/nginx.conf" -p "$T" 2>/dev/null' EXIT

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
B=http://127.0.0.1:8080
echo "== Temel erisim"
check "normal tarayici /"          "$(code -A "$UA" $B/)"             200
check "robots.txt"                 "$(code -A "$UA" $B/robots.txt)"   200
check "statik css"                 "$(code -A "$UA" $B/a.css)"        200

echo "== User-Agent engelleme"
check "python-requests"            "$(code -A 'python-requests/2.31' $B/)" 403
check "curl varsayilan UA"         "$(code $B/)"                            403
check "bos UA"                     "$(code -A '' $B/)"                      403
check "HeadlessChrome"             "$(code -A 'Mozilla/5.0 HeadlessChrome/120' $B/)" 403
check "GPTBot"                     "$(code -A 'Mozilla/5.0 (compatible; GPTBot/1.0)' $B/)" 403
check "Googlebot serbest"          "$(code -A 'Mozilla/5.0 (compatible; Googlebot/2.1)' $B/)" 200

echo "== Honeypot"
check "honeypot 403"               "$(code -A "$UA" $B/.well-known/private-feed.json)" 403
grep -q 'private-feed.json' "$T/logs/honeypot.log" && check "honeypot ayri loga yazildi" ok ok || check "honeypot ayri loga yazildi" yok ok

echo "== Hiz siniri (60 hizli istek, limit 10r/s + burst 20)"
got429=0; for i in $(seq 1 60); do [ "$(code -A "$UA" $B/)" = 429 ] && got429=$((got429+1)); done
[ $got429 -gt 0 ] && check "429 uretildi ($got429/60)" ok ok || check "429 uretildi" yok ok
grep -q 'limiting requests' "$T/logs/error.log" && check "error.log'a limit satiri" ok ok || check "error.log'a limit satiri" yok ok

echo "== Fail2ban filtreleri"
f2b() { fail2ban-regex "$1" "$2" 2>/dev/null | grep -oE 'Lines: [0-9]+ lines, [0-9]+ ignored, [0-9]+ matched'; }
r=$(f2b "$T/logs/honeypot.log" "$HERE/fail2ban/filter.d/nginx-honeypot.conf"); echo "   honeypot:  $r"
echo "$r" | grep -qE ' [1-9][0-9]* matched' && check "honeypot filtresi eslesti" ok ok || check "honeypot filtresi eslesti" yok ok
r=$(f2b "$T/logs/error.log" "$HERE/fail2ban/filter.d/nginx-ratelimit.conf"); echo "   ratelimit: $r"
echo "$r" | grep -qE ' [1-9][0-9]* matched' && check "ratelimit filtresi eslesti" ok ok || check "ratelimit filtresi eslesti" yok ok
r=$(f2b "$T/logs/access.log" "$HERE/fail2ban/filter.d/nginx-badbot.conf"); echo "   badbot:    $r"
echo "$r" | grep -qE ' [1-9][0-9]* matched' && check "badbot filtresi eslesti" ok ok || check "badbot filtresi eslesti" yok ok

echo; echo "SONUC: $PASS basarili, $FAIL basarisiz"
[ $FAIL -eq 0 ]
