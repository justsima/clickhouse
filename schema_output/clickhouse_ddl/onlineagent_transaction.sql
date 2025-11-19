CREATE TABLE IF NOT EXISTS analytics.`onlineagent_transaction`
(
    `id` Int64,
    `uuid` UUID,
    `amount` Decimal64(2),
    `state` UInt16,
    `transaction_type` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32 DEFAULT 0,
    `online_ticket_id` Int32 DEFAULT 0,
    `user_id` Int32,
    `wallet_id` Int32,
    `commision` Float64,
    `commission_state` UInt16,
    `beneficiary_bank_transaction_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
