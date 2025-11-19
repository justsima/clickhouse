CREATE TABLE IF NOT EXISTS analytics.`flatodd_offlineticket`
(
    `id` Int32,
    `ticketID` String,
    `status` LowCardinality(String),
    `is_paid` Bool,
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `confirmed_by_id` Int32 DEFAULT 0,
    `coupon_id` Int32,
    `branch_id` Int32 DEFAULT 0,
    `cancelled_by_id` Int32 DEFAULT 0,
    `paid_by_id` Int32 DEFAULT 0,
    `paid_amount` Decimal64(2),
    `payable_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_settled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `net_win` Float64,
    `slip_computer_class` String,
    `after_0` Float64,
    `before_0` Float64,
    `before_01` Float64,
    `sold_criteria` String,
    `slip_hash` String DEFAULT '',
    `last_payment_receipt` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `remaining_payment_print` Int32,
    `cancelled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `cashback_rule` UInt16 DEFAULT 0,
    `payment_type` UInt16,
    `number_matches` UInt16 DEFAULT 0,
    `compatability` UInt16,
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
