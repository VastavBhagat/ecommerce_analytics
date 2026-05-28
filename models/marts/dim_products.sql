with products as (
    select * from {{ ref('stg_products') }}
),

sales as (
    select
        product_id,
        count(distinct order_id)  as total_orders,
        sum(price)                as total_revenue,
        avg(price)                as avg_price
    from {{ ref('stg_order_items') }}
    group by product_id
)

select
    p.product_id,
    p.product_category,
    p.product_weight_g,
    s.total_orders,
    s.total_revenue,
    round(s.avg_price, 2)         as avg_selling_price
from products p
left join sales s using (product_id)