with source as (
    select * from {{ source('ecommerce', 'raw_order_items') }}
),

cleaned as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date::date    as shipping_limit_date,
        price::float                 as price,
        freight_value::float         as freight_value,
        price + freight_value        as total_item_value
    from source
    where order_id is not null
)

select * from cleaned