with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select
        customer_id,
        min(order_date)           as first_order_date,
        max(order_date)           as last_order_date,
        count(distinct order_id)  as total_orders,
        sum(revenue)              as lifetime_value,
        datediff('day',
            max(order_date),
            current_date())       as days_since_last_order
    from {{ ref('fact_orders') }}
    group by customer_id
)

select
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.first_order_date,
    o.last_order_date,
    o.total_orders,
    o.lifetime_value,
    o.days_since_last_order,
    case
        when o.customer_id is null             then 'never_ordered'
        when o.days_since_last_order > 180     then 'churned'
        when o.days_since_last_order > 90      then 'at risk'
        when o.total_orders > 3                then 'loyal'
        else 'active'
    end                                        as customer_segment
from customers c
left join orders o using (customer_id)