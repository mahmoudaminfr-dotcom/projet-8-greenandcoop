with source_ordered as (

    select
        ctid,
        _airbyte_raw_id as airbyte_id,
        _airbyte_extracted_at as ingested_at,
        'la_madeleine' as station_id,
        "Time" as recorded_time_raw,
        "Temperature" as temperature_raw,
        "Dew_Point" as dew_point_raw,
        "Humidity" as humidity_raw,
        "Wind" as wind_direction_raw,
        "Speed" as wind_speed_raw,
        "Gust" as wind_gust_raw,
        "Pressure" as pressure_raw,
        "Precip__Rate_" as precip_rate_raw,
        "Precip__Accum_" as precip_accum_raw,
        "UV" as uv_raw,
        "Solar" as solar_radiation_raw
    from {{ source('raw', 'wu_la_madeleine_raw') }}

),

day_boundaries as (

    select
        *,
        case
            when recorded_time_raw < lag(recorded_time_raw) over (order by ctid) then 1
            else 0
        end as is_new_day
    from source_ordered

),

day_assigned as (

    select
        *,
        sum(is_new_day) over (order by ctid) as day_offset
    from day_boundaries

),

final as (

    select
        airbyte_id,
        ingested_at,
        station_id,
        to_char(date '2024-10-01' + (day_offset || ' days')::interval, 'YYYY-MM-DD') as recorded_date_raw,
        recorded_time_raw,
        temperature_raw,
        dew_point_raw,
        humidity_raw,
        wind_direction_raw,
        wind_speed_raw,
        wind_gust_raw,
        pressure_raw,
        precip_rate_raw,
        precip_accum_raw,
        uv_raw,
        solar_radiation_raw
    from day_assigned

)

select * from final