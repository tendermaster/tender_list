

```shell

rails generate scaffold post title:string content:text

rails generate scaffold tender tenderId:string title:string description:string organisation:string state:string tender_value:integer submission_open_date:datetime submission_close_date:datetime attachments:references search_data:string

rails generate scaffold attachments name:string tenderId:references

```
- [] add emd,tender_fee,slug,filename,file_path(uuid)

```shell
rails generate migration add_emd_tender_fee_to_tender emd:integer tender_fee:integer
rails generate migration add_filename_to_attachment filename:integer tender_fee:integer
```

- [] add view
- [] add routes

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

