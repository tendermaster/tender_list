

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
[x] add dropdown 1L-20L

[] add faq
[x] disable empty search
[] live chat
[] onboarding tutorial ui js
    [] https://github.com/topics/introjs
    product tour library
    https://github.com/topics/tour
    https://blog.bitsrc.io/7-awesome-javascript-web-app-tour-libraries-6b5d220fb862
[] add pricing page
[] signup
    [] reset password
    [] add services
[] add profile with services for others
    [] https://github.com/norman/friendly_id
[] add gemportal, newspaper (tesseract)
[] add goods/service column to eproc tender
    [] pcs,goods/services

[] signup must
    [] retention
[] seo slow
[] add indian timezone in docker

add col in db
```shell
rails generate migration add_tenderType_to_tenders tender_category:string tender_contract_type:string tender_source:string

```
[x] col txt in attachment
[x] add background job
    [x] sidekiq
    [x] sitemap
    [x] searchkick (large)
[] fix seo down
[] add download queue
[] add redis,rabbitmq in docker compose
[] boost by col
[] add gem
[] login and add keyword
[] search attachment text
[] add profile like tata nexarc
[x] use ts_search sql search
[] implement ts_rank
[] add index in migration
    [] rails to_tsquery
    [] https://pganalyze.com/blog/full-text-search-ruby-rails-postgres
    [] https://www.postgresql.org/docs/current/textsearch-controls.html

[] fix tenderId -> tender_id
[] ocr
[] devise
[] scaff


[] add in one folder
[] fix login signup
[] add sitemap
[] keyword
[] remove ngotenders
[] social media
[] tutorial

fix
tenderId
routes
sitemap
interlinking


bookmark
https://www.tenderdetail.com/registeruser/lmresult?QueryID=43752&SearchBoundary=3

tender status and files
https://wbtenders.gov.in/nicgep/app?page=WebTenderStatusLists&service=page

add to watch list
captacha solve

/tenders/category-search
/tender/abc

/user/query

canonical tag
duplicate


[] https://wbtenders.gov.in/nicgep/app?page=WebTenderStatusLists&service=page

https://www.crunchydata.com/blog/postgres-full-text-search-a-search-engine-in-a-database

https://gem.gov.in/view_contracts
sbt captach
post req

https://tika.apache.org/
tesseract image
https://medium.com/@masreis/text-extraction-and-ocr-with-apache-tika-302464895e5f
https://cwiki.apache.org/confluence/display/TIKA/TikaOCR

storage.ngotenders.in
ebs (ssd) -> ebs(hdd) -> efs




