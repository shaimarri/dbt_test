with lkp_dw_cust as (
select CUSTOMER_KEY, INST_SYMBOL_CD 
from {{ source('DWDB01', 'DW_CUSTOMER') }}
where inst_symbol_cd>'' and lower(account_status_ds)='active' and 
lower(primary_instituiton_in)='y' and lower(billing_profile_in) = 'n') --and customer_sfx_cd = '' and lower(archive_in) = 'n')

select * from lkp_dw_cust