

```shell

rails generate scaffold post title:string content:text

rails generate scaffold tender tender_id:string title:string description:string organisation:string state:string tender_value:integer submission_open_date:datetime submission_close_date:datetime attachments:references search_data:string

rails generate scaffold attachments name:string tender_id:references

```
- [] add emd,tender_fee,slug,filename,file_path(uuid)

```shell
rails generate migration add_emd_tender_fee_to_tender emd:integer tender_fee:integer
rails generate migration add_filename_to_attachment filename:integer tender_fee:integer

rails generate model search_query query:string



```


[] 

```js
$('#buyer_category > option').each(function (){ console.log($(this).text()) })
```

[] add only boq in desc
[] add download link in tenders table
[] use json for storing boq
[] add recaptacha for download
[] update tender
[] expired card
    [] ask to search new
[] add statewise search





scraper -> rabbit -> python (download- unzip - upload to s3 & put id in db > scan if boq add text to db)

[] upload downloader with cred
    [] seed db
[] upload site

[] remove common error

app.html
2.52 KB

[x] finalize ui, env variables
[x] upload site
[x] clear rabbitmq
[x] test download recaptacha, aws
[-] clear s3    
[] start attachment downloader
[] clean attach, tenders
[] restart batch scrape

[] add competitor

```shell
docker compose exec -it rails bash

rails generate model SubscriptionPlans name:string price:decimal validity:integer 

rails generate model Subscriptions start_date:datetime validity:integer order_id:string price:decimal subscription_plan:references plan_name:string

trial
paid
premium
custom_qoute

rails generate scaffold Coupon coupon_code:text:uniq start_date:datetime end_date:datetime validity_seconds:integer is_valid:boolean

rails g migration AddBidResultToTenders bid_result:text

seller, item_category, item, price, participation_date, mes_mii_status, qualification, bid_data


```

```ruby
add_reference :subscriptions, :coupons, null: true, foreign_key: true
```

redeem
account specific coupon 1 time validity

2 tier search ranking

[] refactor to use elasticsearch in mail search
[] add min max
[] compare db and eastic search results

```ruby


```

https://www.tenderdetail.com/Tenders-By-Category
```js
copy(Array.from(document.querySelectorAll("body > div.mainIndustryListPage > div > div.m-diwali-bg > div.page-block .catList p a")).map(e => e.text).join("\n"))
```

```postgresql

ALTER TABLE public.attachments
DROP CONSTRAINT fk_rails_b08821b603,
ADD CONSTRAINT fk_rails_b08821b603 FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE;
```

```shell
rails g migration AddIndexToTenders tender_source bid_result_status
```

add keywords url
wb | wbtenders.gov.in

http://localhost:3000/tender/1ApMradAc9B42x6oKsXBeN

- add 50d old 
  - add stutus col, (completed cancelled, )
  - sort and run on loop
    - oldest -> expired
      - add completed, cancelled, pending status

- add index name to one place
- change profile title
- 

