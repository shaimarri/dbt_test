{{  config(    
    materialized='incremental',    
    incremental_strategy='insert_overwrite',
    unique_key='PROCESSED_DT')
}}

with stg_src as (
    select BATCHLOADSTATS_COLLECTIONID as COLLECTION_ID,
    BATCHLOADSTATS_INSTSYMBOL as INST_SYMBOL_CD,
    BATCHLOADSTATS_INPUTFILENAME as INPUT_FILE_NM,
    to_date(to_char(BATCHLOADSTATS_DATEPROCESSED)) as PROCESSED_DT,
    BATCHLOADSTATS_LOCALSYSTEMID as LOCAL_SYSTEM_ID,
    BATCHLOADSTATS_INCOMINGOCLCNUMBER as INCOMING_OCLC_NR,
    BATCHLOADSTATS_MATCHEDOCLCNUMBER as MATCHED_OCLC_NR,
    BATCHLOADSTATS_ASSIGNEDOCLCNUMBER as ASSIGNED_OCLC_NR,
    BATCHLOADSTATS_BATCHEXCEPTIONS_BATCHEXCEPTION_ERRORLEVEL as ERROR_LEVEL,
    BATCHLOADSTATS_BATCHEXCEPTIONS_BATCHEXCEPTION_STEPNAME as STEP_NAME,
    BATCHLOADSTATS_BATCHEXCEPTIONS_BATCHEXCEPTION_ERRORDETAIL as ERROR_DETAIL_TX,
    BATCHLOADSTATS_BATCHEXCEPTIONS_BATCHEXCEPTION_ERRORMESSAGE as ERROR_MESSAGE_TX,
    to_timestamp(to_char(BATCHLOADSTATS_DATEPROCESSED)) as CONVERTED_INPUT_FILE_TS
    from {{ source('DWDB01', 'PRESTG_BL_BIB_STATS_JSON_VW') }}
),

max_conv_file_ts as (
    select customer_key,COLLECTION_ID,INST_SYMBOL_CD,GROUP_SYMBOL_CD,INPUT_FILE_NM,LOCAL_SYSTEM_ID,max(CONVERTED_INPUT_FILE_TS) as CONVERTED_INPUT_FILE_TS
    from stg_src
    group by customer_key,COLLECTION_ID,INST_SYMBOL_CD,GROUP_SYMBOL_CD,INPUT_FILE_NM,LOCAL_SYSTEM_ID
),

joined_max_input_file as (
    select ss.COLLECTION_ID, ss.INST_SYMBOL_CD, ss.INPUT_FILE_NM, ss.PROCESSED_DT, 
    ss.LOCAL_SYSTEM_ID, ss.INCOMING_OCLC_NR, ss.MATCHED_OCLC_NR, ss.ASSIGNED_OCLC_NR , 
    IFF(ss.ERROR_LEVEL=1,1,0) as ERROR_LEVEL_1_QY,
    IFF(ss.ERROR_LEVEL=2,1,0) as ERROR_LEVEL_2_QY,
    IFF(ss.ERROR_LEVEL=3,1,0) as ERROR_LEVEL_3_QY,
    mcft.CONVERTED_INPUT_FILE_TS,
    case when mcft.CONVERTED_INPUT_FILE_TS is not null then 1 else 0 end as CONVERTED_INPUT_FILE_IN  from stg_src ss
    left join max_conv_file_ts mcft on 
    ss.customer_key = mcft.customer_key
    and ss.COLLECTION_ID = mcft.COLLECTION_ID 
    and ss.INST_SYMBOL_CD = mcft.INST_SYMBOL_CD
    and ss.GROUP_SYMBOL_CD = mcft.GROUP_SYMBOL_CD
    and ss.INPUT_FILE_NM = mcft.INPUT_FILE_NM
    and ss.LOCAL_SYSTEM_ID = mcft.LOCAL_SYSTEM_ID
)

select * from joined_max_input_file
{% if is_incremental() %}
  -- this filter will only be applied on an incremental run  
  where PROCESSED_DT >= (select max(PROCESSED_DT) from {{ this }})
{% endif %}