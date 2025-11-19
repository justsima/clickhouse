CREATE TABLE IF NOT EXISTS analytics.`flatodd_onlineticket`
(
    `id` Int32,
    `stake` Float64,
    `possible_win` Float64,
    `ticketID` String,
    `is_paid` Bool,
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `user_id` Int32 DEFAULT 0,
    `status` LowCardinality(String),
    `paid_amount` Decimal64(2),
    `payable_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_settled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `slip_computer_class` String,
    `after_0` Float64,
    `before_0` Float64,
    `before_01` Float64,
    `channel` String,
    `updated_at` DateTime64(6, 'UTC'),
    `slip_hash` String DEFAULT '',
    `nonwithdrawable` Float64,
    `payable` Float64,
    `cashback_rule` UInt16 DEFAULT 0,
    `payment_type` UInt16,
    `number_matches` UInt16 DEFAULT 0,
    `compatability` UInt16,
    `agent_id` Int32 DEFAULT 0,
    `cashout_rule` UInt16 DEFAULT 0,
    `slip_match_hash` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
