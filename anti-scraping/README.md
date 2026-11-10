# Anti-Scraping (veri kazima) koruma paketi

Tum sitelerinizde ortak kullanilacak, yerel olarak test edilmis koruma yapilandirmalari.
Test: `bash anti-scraping/test/run-tests.sh` (nginx, fail2ban ve curl kurulu olmali).

## Katmanlar

| Katman | Dosya | Ne yapar |
|---|---|---|
| Cloudflare | `cloudflare/waf-rules.md` | Bot korumasi, rate limit, WAF kurallari, IP/ASN engeli |
| Nginx | `nginx/anti-scraping-http.conf`, `nginx/anti-scraping-server.conf` | Hiz siniri (429), kazima UA'lari (403), honeypot, sadece-Cloudflare erisimi |
| Fail2ban | `fail2ban/filter.d/*`, `fail2ban/jail.d/anti-scraping.conf` | Honeypot'a dokunani 30 gun, limiti asani 6 saat, bot UA'yi 24 saat yasaklar |
| Web | `web/robots.txt`, `web/honeypot-snippet.html` | Kibar botlari uzak tutar, gizli tuzak link |

## Kurulum (her sunucuda)

```bash
sudo cp anti-scraping/nginx/anti-scraping-http.conf /etc/nginx/
sudo cp anti-scraping/nginx/anti-scraping-server.conf /etc/nginx/
sudo mkdir -p /var/www/anti-scraping && sudo cp anti-scraping/web/robots.txt /var/www/anti-scraping/
```

`/etc/nginx/nginx.conf` icinde `http { ... }` blogunun icine:
```nginx
include /etc/nginx/anti-scraping-http.conf;
```

Her sitenin `server { ... }` blogunun icine (ornek: `nginx/example-site.conf`):
```nginx
include /etc/nginx/anti-scraping-server.conf;
location / { limit_req zone=scrape_page burst=20 nodelay; ... }
```

Cloudflare **kullanmiyorsaniz** `anti-scraping-server.conf` icindeki
`if ($not_cloudflare) { return 444; }` satirini silin; yoksa herkesi engeller.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Fail2ban:
```bash
sudo cp anti-scraping/fail2ban/filter.d/*.conf /etc/fail2ban/filter.d/
sudo cp anti-scraping/fail2ban/jail.d/anti-scraping.conf /etc/fail2ban/jail.d/
sudo touch /var/log/nginx/honeypot.log
sudo systemctl restart fail2ban && sudo fail2ban-client status
```

Honeypot linkini (`web/honeypot-snippet.html`) her sayfanin `<body>` sonuna ekleyin.

## Ayar notlari
- Hiz siniri: `10r/s` + `burst=20` normal kullanici icin rahattir. Agresif istiyorsaniz `5r/s`, `burst=10`.
- Kendi izleme/uptime araclariniz curl kullaniyorsa `bad_bot` map'inden `~*curl/` satirini kaldirin veya araca ozel tanimlayici verin.
- Cloudflare arkasindaysaniz fail2ban'in iptables ile banlamasi ise yaramaz (istek Cloudflare IP'sinden gelir);
  `banaction = cloudflare` kullanin (`/etc/fail2ban/action.d/cloudflare.conf` icine API token girin).
- Cloudflare IP listesi zamanla degisir; yilda bir `https://www.cloudflare.com/ips/` ile karsilastirin.
