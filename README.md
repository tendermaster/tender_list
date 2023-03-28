

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

