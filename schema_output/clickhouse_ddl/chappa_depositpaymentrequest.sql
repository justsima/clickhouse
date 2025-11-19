CREATE TABLE IF NOT EXISTS analytics.`chappa_depositpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `tx_ref` String,
    `state` UInt16,
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `charge` Float64,
    `original_amount` Decimal64(2),
    `method` String,
    `chapa_reference` String,
    `useridentifier` String,
    `bank_id` Int64 DEFAULT 0,
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
