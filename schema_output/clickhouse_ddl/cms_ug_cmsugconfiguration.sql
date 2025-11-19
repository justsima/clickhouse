CREATE TABLE IF NOT EXISTS analytics.`cms_ug_cmsugconfiguration`
(
    `configuration_ptr_id` Int32,
    `base_url` String DEFAULT '',
    `brand_id` Int32 DEFAULT 0,
    `operator_id` Int32 DEFAULT 0,
    `access_token` String DEFAULT '',
    `license_number` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
