with source as (
    select * from {{ source('ecommerce', 'raw_order_payments') }}
),

cleaned as (
    select
        order_id,
        payment_sequential,
        lower(payment_type)          as payment_type,
        payment_installments,
        payment_value::float         as payment_value
    from source
    where order_id is not null
)

select * from cleaned
