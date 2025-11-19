CREATE TABLE IF NOT EXISTS analytics.`flatodd_member`
(
    `member_type` String,
    `withdraw_transaction_setting` String,
    `affiliate_provider` String,
    `deposit_count` String,
    `identification_type` String,
    `source_of_fund` String,
    `deposit_transaction_setting` String,
    `max_daily_deposit_number` String,
    `max_daily_wallet_received_number` String,
    `max_daily_wallet_sent_number` String,
    `max_daily_withdraw_number` String,
    `wallet_transfer_setting` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
