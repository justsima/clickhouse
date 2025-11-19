CREATE TABLE IF NOT EXISTS analytics.`chappa_withdrawpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `state` UInt16,
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `account_name` Int32,
    `account_number` Int32,
    `bank_id` Int64,
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `reference` String,
    `original_amount` Decimal64(2),
    `method` String,
    `chapa_reference` String,
    `charge` Float64,
    `chapa_configuration_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
