select  * 
from {{ source('DWDB01', 'PRESTG_BL_BIB_STATS_JSON_VW') }}