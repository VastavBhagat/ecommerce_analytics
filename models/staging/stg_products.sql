with
    source as (select * from {{ source("ecommerce", "raw_products") }}),

    cleaned as (
        select
            product_id,
            coalesce(product_category_name, 'unknown') as product_category,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        from source
        where product_id is not null
    )

select *
from cleaned
