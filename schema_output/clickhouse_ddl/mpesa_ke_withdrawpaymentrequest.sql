CREATE TABLE IF NOT EXISTS analytics.`mpesa_ke_withdrawpaymentrequest`
(
    `id` Int64,
    `transaction_reference` String,
    `initiator_name` String,
    `command_id` Int32,
    `party_a` String,
    `party_b` String,
    `remarks` String,
    `queue_timeout_url` String,
    `result_url` String,
    `occasion` String,
    `conversation_id` Int32,
    `transaction_id` Int32,
    `originator_conversation_id` Int32,
    `response_code` String,
    `response_description` String,
    `result_type` Int32 DEFAULT 0,
    `result_code` Int32 DEFAULT 0,
    `result_description` String,
    `user_identifier` Int32,
    `comment` String,
    `amount` Decimal64(2),
    `status` UInt16,
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
