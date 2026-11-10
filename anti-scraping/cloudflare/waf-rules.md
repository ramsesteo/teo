# Cloudflare ayarlari (tum domainlere ayni ayarlari uygulayin)

## 1. Panelden acilacaklar
- Security > Bots: **Bot Fight Mode** (Free) veya **Super Bot Fight Mode** (Pro+) -> Definitely automated: Block, Likely automated: Managed Challenge
- Security > Bots: **Block AI Scrapers and Crawlers** -> On
- Security > Settings: Security Level **Medium** veya **High**, Browser Integrity Check **On**
- SSL/TLS: **Full (strict)**; sunucuda sadece Cloudflare IP'lerine izin verin (nginx `not_cloudflare` kurali)
- Rules > Settings: **Hotlink Protection** On (isterseniz)

## 2. Rate Limiting kurali (Security > WAF > Rate limiting rules)
- Name: `page-rate-limit`
- If incoming requests match: `(not http.request.uri.path matches "\.(css|js|png|jpe?g|gif|svg|webp|ico|woff2?)$")`
- Same: IP
- Requests: `60` per `1 minute`
- Action: **Block** (veya Managed Challenge), duration 10 minutes

## 3. Custom rules (Security > WAF > Custom rules)

### a) Kazima araclari ve AI botlari -> Block
```
(http.user_agent eq "")
or (lower(http.user_agent) contains "python-requests")
or (lower(http.user_agent) contains "python-urllib")
or (lower(http.user_agent) contains "aiohttp")
or (lower(http.user_agent) contains "scrapy")
or (lower(http.user_agent) contains "go-http-client")
or (lower(http.user_agent) contains "libwww-perl")
or (lower(http.user_agent) contains "okhttp")
or (lower(http.user_agent) contains "node-fetch")
or (lower(http.user_agent) contains "axios")
or (lower(http.user_agent) contains "curl/")
or (lower(http.user_agent) contains "wget/")
or (lower(http.user_agent) contains "headlesschrome")
or (lower(http.user_agent) contains "phantomjs")
or (lower(http.user_agent) contains "httrack")
or (lower(http.user_agent) contains "gptbot")
or (lower(http.user_agent) contains "claudebot")
or (lower(http.user_agent) contains "ccbot")
or (lower(http.user_agent) contains "bytespider")
or (lower(http.user_agent) contains "amazonbot")
or (lower(http.user_agent) contains "ahrefsbot")
or (lower(http.user_agent) contains "semrushbot")
or (lower(http.user_agent) contains "mj12bot")
```
Action: **Block**

### b) Honeypot'a dokunan -> Block
```
(http.request.uri.path eq "/.well-known/private-feed.json")
```
Action: **Block**  (Isterseniz Cloudflare Lists ile IP'yi listeye ekleyen bir Worker da baglayabilirsiniz.)

### c) Belirli kisi: IP / ASN / ulke
```
(ip.src in {203.0.113.0/24 198.51.100.7})
or (ip.src.asnum in {12345})
```
Action: **Block**. Hosting/VPS saglayicilarindan gelen (veri merkezi) trafigi sorgulamak icin:
```
(ip.src.asnum in {16509 14618 15169 8075 14061 20473 24940 16276 63949 51167})
and not cf.client.bot
```
Action: **Managed Challenge** (AWS, GCP, Azure, DigitalOcean, Vultr, Hetzner, OVH, Linode, Contabo)

### d) Tarayici gibi gorunmeyen istekler -> Managed Challenge
```
(cf.threat_score gt 10) and not cf.client.bot
```
Action: **Managed Challenge**

## 4. Terraform ile tum domainlere ayni anda uygulamak
Cok sayida domain varsa `cloudflare_ruleset` kaynagini bir `for_each` ile zone listesine uygulayin;
boylece kurallar tek yerden yonetilir.
