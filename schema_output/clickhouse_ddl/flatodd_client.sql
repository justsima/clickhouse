CREATE TABLE IF NOT EXISTS analytics.`flatodd_client`
(
    `id` Int32,
    `user_id` Int32,
    `data_access_period` Int32 DEFAULT 0,
    `access_end_date` Date DEFAULT toDate(0),
    `access_start_date` Date DEFAULT toDate(0),
    `maximum_allowed_deposit` Int32 DEFAULT 0,
    `is_mainstaff` Bool,
    `group_id` Int32 DEFAULT 0,
    `phonenumber` Int32,
    `is_2fa_enabled` Bool,
    `is_2fa_setup_complete` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
