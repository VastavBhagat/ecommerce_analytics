with source as (
    select * from {{ source('ecommerce', 'raw_orders') }}
),

cleaned as (
    select
        order_id,
        customer_id,
        lower(order_status)                        as order_status,
        order_purchase_timestamp::date             as order_date,
        order_approved_at::date                    as approved_date,
        order_delivered_customer::date             as delivered_date,
        order_estimated_delivery::date             as estimated_date,
        datediff('day',
            order_purchase_timestamp,
            order_delivered_customer)              as delivery_days,
        case
            when order_delivered_customer::date
                 <= order_estimated_delivery::date
            then true
            else false
        end                                        as delivered_on_time
    from source
    where order_id is not null
)

select * from cleaned