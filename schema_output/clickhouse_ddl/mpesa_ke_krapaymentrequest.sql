CREATE TABLE IF NOT EXISTS analytics.`mpesa_ke_krapaymentrequest`
(
    `id` Int64,
    `conversation_id` Int32 DEFAULT 0,
    `transaction_id` Int32 DEFAULT 0,
    `response_description` String DEFAULT '',
    `result_description` String DEFAULT '',
    `account_reference` Int32 DEFAULT 0,
    `transaction_reference` String,
    `response_code` String DEFAULT '',
    `result_type` LowCardinality(String) DEFAULT '',
    `result_code` String DEFAULT '',
    `tax_start_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `tax_end_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `amount` Decimal64(2),
    `comment` String,
    `status` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
