with orders as (
    select * from {{ ref('stg_orders') }}
),

items as (
    select
        order_id,
        count(order_item_id)     as item_count,
        sum(price)               as revenue,
        sum(freight_value)       as freight_total,
        sum(total_item_value)    as order_total
    from {{ ref('stg_order_items') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.delivery_days,
    o.delivered_on_time,
    i.item_count,
    i.revenue,
    i.freight_total,
    i.order_total
from orders o
inner join items i using (order_id)