CREATE TABLE IF NOT EXISTS analytics.`mpesa_et_mpesaetconfiguration`
(
    `configuration_ptr_id` Int32,
    `api_url` String,
    `token_url` String,
    `grant_type` LowCardinality(String),
    `b2c_short_code` String DEFAULT '',
    `b2c_consumer_key` String DEFAULT '',
    `b2c_consumer_secret` String DEFAULT '',
    `b2c_initiator_name` String DEFAULT '',
    `b2c_initiator_password` String DEFAULT '',
    `c2b_passkey` String DEFAULT '',
    `c2b_short_code` String DEFAULT '',
    `c2b_consumer_key` String DEFAULT '',
    `c2b_consumer_secret` String DEFAULT '',
    `deposit_callback_url` String,
    `withdraw_callback_url` String,
    `public_certificate_path` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
