CREATE TABLE IF NOT EXISTS analytics.`mpesa_et_historicalmpesaetconfiguration`
(
    `id` Int32,
    `configuration_ptr_id` Int32 DEFAULT 0,
    `config_name` String,
    `updated_at` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
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
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
