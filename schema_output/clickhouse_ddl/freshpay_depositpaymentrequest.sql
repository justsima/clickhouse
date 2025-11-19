CREATE TABLE IF NOT EXISTS analytics.`freshpay_depositpaymentrequest`
(
    `id` Int64,
    `currency` String,
    `payment_method` String DEFAULT '',
    `freshpay_status` LowCardinality(String) DEFAULT '',
    `pay_drc_reference` String DEFAULT '',
    `freshpay_description` String DEFAULT '',
    `reference` String DEFAULT '',
    `financial_institution_id` Int32 DEFAULT 0,
    `freshpay_reference` String DEFAULT '',
    `amount` Decimal64(2),
    `useridentifier` String,
    `transaction_reference` String,
    `comment` String DEFAULT '',
    `status` Int32,
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
