

```html
<td class="py-4 px-6 blur-sm select-none">2023_DDA_736484_1</td>


```
```bash
rails assets:precompile
rails db:create
rails db:migrate

```
[x] add .env

[x] master key
`validate_secret_key_base': Missing `secret_key_base` for 'production' environment, set this string with `bin/rails credentials:edit` (ArgumentError)
https://stackoverflow.com/questions/51466887/rails-how-to-fix-missing-secret-key-base-for-production-environment
env?

[x] db:create
[x] db:migrate

[x] npm install
[x] assets precompile
[] restart

[] elastic connection
[] sudo docker exec -it tender_list-rails-1 rails searchkick:reindex CLASS=Tender
    [] index at start


[x] change to asset compile
[x] nginx  proxy manager
[x] handle 404
[x] change 500 page public
[x] add sitemap
[x] add docker support

[x] use git
[] sync config
==

[] connect cloudflare
[] start site
[] start scraper
[] add sitemap cron

[x] fix init
[x] fix elastic search host
[x] Docker file


==
[] add sitemap cron
    ```sh
    docker exec rails sitemap:refresh/create

    ```
[x] remove extracted sitemap files


/ home
/state/delhi
/org/ndmc
/tender/title-slug/uuid

- 2 col
- latest news (ghost blog api)
- subscribe (email,number,name)
- sign up
- TODO: set is visible to no and insert new id (transaction)
    - index tenderId
    - if find
        - update
        - insert
    - else
        - insert
        -

```



```
admin@example.com
admin@ngotenders.in

VheKD164dq2FXXS4

```
```nginx
location / {
  root /data/ngotenders.in/public;
}

```


[] add filter
[x] seo title
[] check controller filter
[] add dropdown 1L-20L


